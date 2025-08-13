import torch
from transformers import CLIPProcessor, CLIPModel
from PIL import Image
import numpy as np
from typing import List, Dict, Tuple, Optional
import requests
from datetime import datetime
from pathlib import Path
from flask import current_app
from app.models.models import db, User, Wardrobe, WardrobeItem, Style, PreferredStyle, Weather
import logging
import os

class StyleRecommendationService:
    def __init__(self):
        try:
            # 1) from_pretrained가 튜플을 반환한다면 아래처럼 언패킹:
            # self.model, _ = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
            
            # 2) 일반적으로는 단일 객체 반환, 타입 검사 오류 시 아래와 같이 type:ignore 처리:
            self.model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")  # type: ignore
            self.processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
            
            self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            self.model.to(self.device)
            logging.info("CLIP 모델 로드 완료")
        except Exception as e:
            logging.error(f"CLIP 모델 로드 실패: {e}")
            raise

    def load_wardrobe_data(self, user_id: int) -> List[Dict]:
        try:
            wardrobe_items = db.session.query(WardrobeItem).join(Wardrobe).filter(
                Wardrobe.user_id == user_id
            ).all()
            items_data = []
            for item in wardrobe_items:
                image_path = Path(item.image_path) if item.image_path else None
                if not image_path or not image_path.exists():
                    logging.warning(f"이미지 파일이 존재하지 않습니다: {image_path}")
                    continue

                metadata = {
                    'name': item.name,
                    'category': item.category,
                    'color': item.color,
                    'brand': item.brand
                }
                temperature_range = self._get_temperature_range(item.category)
                items_data.append({
                    'id': item.item_id,
                    'image_path': str(image_path),
                    'metadata': metadata,
                    'temperature_range': temperature_range,
                    'created_at': item.created_at,
                    'image_embedding': item.image_embedding,
                    'text_embedding': item.text_embedding,
                    'combined_embedding': item.combined_embedding
                })
            logging.info(f"사용자 {user_id}의 옷장 데이터 {len(items_data)}개 로드 완료")
            return items_data
        except Exception as e:
            logging.error(f"옷장 데이터 로드 실패: {e}")
            return []

    def _get_temperature_range(self, category: str) -> Tuple[float, float]:
        temperature_ranges = {
            '패딩': (-10, 10), '코트': (0, 15), '자켓': (5, 20), '니트': (5, 25),
            '맨투맨': (10, 25), '후드티': (10, 25), '셔츠': (15, 30), '티셔츠': (20, 35),
            '반팔': (25, 40), '민소매': (25, 40), '청바지': (0, 35), '슬랙스': (10, 30),
            '반바지': (20, 40), '치마': (15, 35), '운동화': (0, 40), '구두': (5, 35), '샌들': (20, 40)
        }
        return temperature_ranges.get(category, (10, 30))

    def get_weather_data(self, city_name: str) -> Optional[Dict]:
        try:
            api_key = os.environ.get('OPENWEATHER_API_KEY')
            if not api_key:
                logging.error("OPENWEATHER_API_KEY 환경변수가 설정되어 있지 않습니다.")
                return None
            url = f'http://api.openweathermap.org/data/2.5/weather?q={city_name}&appid={api_key}&units=metric'
            response = requests.get(url, timeout=10)
            if response.status_code != 200:
                logging.error(f"날씨 API 호출 실패: {response.status_code}")
                return None
            data = response.json()
            return {
                'city': data['name'],
                'temperature': data['main']['temp'],
                'weather': data['weather'][0]['main'],
                'description': data['weather'][0]['description'],
                'humidity': data['main']['humidity'],
                'wind_speed': data['wind']['speed']
            }
        except Exception as e:
            logging.error(f"날씨 데이터 로드 실패: {e}")
            return None

    def filter_by_temperature(self, items: List[Dict], current_temp: float) -> List[Dict]:
        suitable_items = []
        for item in items:
            min_temp, max_temp = item['temperature_range']
            if min_temp <= current_temp <= max_temp or abs(current_temp - min_temp) <= 5 or abs(current_temp - max_temp) <= 5:
                suitable_items.append(item)
        logging.info(f"온도 필터링 완료: {len(suitable_items)}/{len(items)}개 아이템 선택")
        return suitable_items

    def get_user_style_preferences(self, user_id: int) -> List[str]:
        try:
            preferred_styles = db.session.query(Style).join(PreferredStyle).filter(
                PreferredStyle.user_id == user_id
            ).all()
            return [style.name for style in preferred_styles]
        except Exception as e:
            logging.error(f"사용자 스타일 선호도 조회 실패: {e}")
            return []

    def calculate_cosine_similarity(self, vec1: np.ndarray, vec2: np.ndarray) -> float:
        try:
            dot_product = np.dot(vec1, vec2)
            norm1 = np.linalg.norm(vec1)
            norm2 = np.linalg.norm(vec2)
            if norm1 == 0 or norm2 == 0:
                return 0.0
            return float(dot_product / (norm1 * norm2))
        except Exception as e:
            logging.error(f"유사도 계산 실패: {e}")
            return 0.0

    def get_text_embedding(self, text: str) -> np.ndarray:
        try:
            inputs = self.processor(text=[text], return_tensors="pt", padding=True)
            # processor의 반환값 딕셔너리 각 tensor를 device로 이동
            inputs = {k: v.to(self.device) for k, v in inputs.items()}
            with torch.no_grad():
                text_features = self.model.get_text_features(**inputs)
            return text_features.cpu().numpy().flatten()
        except Exception as e:
            logging.error(f"텍스트 임베딩 생성 실패: {e}")
            return np.zeros(512, dtype=np.float32)

    def recommend_styles(self, user_id: int, city_name: str, top_n: int = 10) -> List[Dict]:
        try:
            wardrobe_items = self.load_wardrobe_data(user_id)
            if not wardrobe_items:
                return []

            weather_data = self.get_weather_data(city_name)
            if not weather_data:
                return []

            current_temp = weather_data['temperature']
            suitable_items = self.filter_by_temperature(wardrobe_items, current_temp)
            if not suitable_items:
                return []

            user_styles = self.get_user_style_preferences(user_id)
            style_text = " ".join(user_styles) if user_styles else "casual style"
            user_style_embedding = self.get_text_embedding(style_text)

            recommendations = []
            for item in suitable_items:
                combined_embedding = item['combined_embedding']
                similarity = self.calculate_cosine_similarity(user_style_embedding, combined_embedding)
                recommendations.append({
                    'item_id': item['id'],
                    'image_path': item['image_path'],
                    'metadata': item['metadata'],
                    'temperature_range': item['temperature_range'],
                    'similarity_score': similarity
                })
            recommendations.sort(key=lambda x: x['similarity_score'], reverse=True)
            return recommendations[:top_n]
        except Exception as e:
            logging.error(f"추천 실패: {e}")
            return []
