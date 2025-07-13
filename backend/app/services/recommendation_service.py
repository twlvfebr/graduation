import torch
from transformers import CLIPProcessor, CLIPModel
from PIL import Image
import numpy as np
from typing import List, Dict
import requests
from datetime import datetime
import os

class RecommendationService:
    def __init__(self):
        self.model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
        self.processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
        
    def get_image_embedding(self, image_path: str) -> np.ndarray:
        """이미지의 CLIP 임베딩을 계산합니다."""
        image = Image.open(image_path)
        inputs = self.processor(images=image, return_tensors="pt")
        image_features = self.model.get_image_features(**inputs)
        return image_features.detach().numpy()
    
    def get_text_embedding(self, text: str) -> np.ndarray:
        """텍스트의 CLIP 임베딩을 계산합니다."""
        inputs = self.processor(text=text, return_tensors="pt", padding=True)
        text_features = self.model.get_text_features(**inputs)
        return text_features.detach().numpy()
    
    def calculate_similarity(self, vec1: np.ndarray, vec2: np.ndarray) -> float:
        """두 벡터 간의 코사인 유사도를 계산합니다."""
        return np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2))
    
    def get_weather_recommendation(self, temperature: float) -> List[str]:
        """날씨에 따른 의류 추천 태그를 반환합니다."""
        if temperature < 5:
            return ["패딩", "코트", "목도리", "장갑", "두꺼운 니트"]
        elif temperature < 15:
            return ["자켓", "니트", "긴팔", "청바지"]
        elif temperature < 25:
            return ["셔츠", "후드티", "맨투맨", "청바지", "슬랙스"]
        else:
            return ["반팔", "반바지", "민소매", "린넨", "캐주얼"]
    
    def recommend_outfit(self, 
                        user_id: int,
                        weather_data: Dict,
                        style_preferences: List[str],
                        wardrobe_items: List[Dict]) -> Dict:
        """사용자에게 맞는 코디를 추천합니다."""
        # 날씨 기반 필터링
        weather_tags = self.get_weather_recommendation(weather_data['temperature'])
        
        # 스타일 선호도 기반 필터링
        style_embedding = self.get_text_embedding(" ".join(style_preferences))
        
        # 의류 아이템 필터링 및 점수 계산
        scored_items = []
        for item in wardrobe_items:
            # 날씨 태그와 일치하는지 확인
            weather_match = any(tag in item['category'] or tag in item['subcategory'] 
                              for tag in weather_tags)
            
            if weather_match:
                # 스타일 유사도 계산
                item_embedding = np.array(item['embedding'])
                style_similarity = self.calculate_similarity(style_embedding, item_embedding)
                
                scored_items.append({
                    'item': item,
                    'score': style_similarity
                })
        
        # 상위 점수 아이템 선택
        scored_items.sort(key=lambda x: x['score'], reverse=True)
        top_items = scored_items[:5]  # 상위 5개 아이템 선택
        
        # 코디 구성
        outfit = {
            'items': [item['item'] for item in top_items],
            'weather_tags': weather_tags,
            'style_tags': style_preferences,
            'created_at': datetime.utcnow()
        }
        
        return outfit
    
    def detect_clothing_items(self, image_path: str) -> List[Dict]:
        """YOLO를 사용하여 이미지에서 의류 아이템을 감지합니다."""
        # YOLO 모델 로드 및 실행
        # 실제 구현에서는 YOLO 모델을 사용하여 객체 감지 수행
        # 여기서는 예시로 더미 데이터 반환
        return [
            {
                'category': '상의',
                'subcategory': '티셔츠',
                'confidence': 0.95,
                'bbox': [100, 100, 200, 200]
            }
        ] 