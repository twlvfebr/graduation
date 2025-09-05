import torch
from transformers import CLIPProcessor, CLIPModel
from PIL import Image, UnidentifiedImageError
import numpy as np
import os
import logging
from pathlib import Path
from typing import Optional, Tuple
from app.models.models import db, WardrobeItem

class EmbeddingGenerator:
    """
    CLIP 모델을 사용하여 이미지와 텍스트 임베딩을 생성하고 관리하는 클래스
    """
    def __init__(self, model_name: str = "openai/clip-vit-base-patch32"):
        """
        CLIP 모델 초기화
        
        Args:
            model_name (str): 사용할 CLIP 모델 이름 (기본값: "openai/clip-vit-base-patch32")
        """
        self.model_name = model_name
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self._load_model()
    
    def _load_model(self):
        """CLIP 모델과 프로세서 로드"""
        try:
            logging.info(f"Loading CLIP model: {self.model_name}")
            self.model = CLIPModel.from_pretrained(self.model_name)
            self.processor = CLIPProcessor.from_pretrained(self.model_name)
            self.model = self.model.to(self.device)
            self.model.eval()  # 평가 모드로 설정
            logging.info(f"CLIP 모델 로드 완료 (장치: {self.device})")
        except Exception as e:
            error_msg = f"CLIP 모델 초기화 실패: {str(e)}"
            logging.error(error_msg, exc_info=True)
            raise RuntimeError(error_msg) from e

    def _generate_image_embedding(self, image_path: str) -> Optional[np.ndarray]:
        """이미지 파일에서 임베딩 벡터 생성"""
        try:
            with Image.open(image_path) as img:
                # 이미지가 유효한지 확인
                img.verify()
                img = Image.open(image_path).convert("RGB")  # 다시 열기
                
                # 이미지 전처리 및 임베딩
                inputs = self.processor(images=img, return_tensors="pt")
                inputs = {k: v.to(self.device) for k, v in inputs.items()}
                
                with torch.no_grad():
                    image_features = self.model.get_image_features(**inputs)
                
                return image_features.cpu().numpy().flatten()
                
        except (UnidentifiedImageError, OSError) as e:
            logging.error(f"이미지 파일을 열 수 없습니다: {image_path} - {e}")
            return None
        except Exception as e:
            logging.error(f"이미지 임베딩 생성 중 오류: {e}", exc_info=True)
            return None

    def _generate_text_embedding(self, text: str) -> Optional[np.ndarray]:
        """텍스트에서 임베딩 벡터 생성"""
        try:
            if not text or not text.strip():
                return None
                
            inputs = self.processor(
                text=text, 
                return_tensors="pt", 
                padding=True, 
                truncation=True,
                max_length=77,  # CLIP의 최대 시퀀스 길이
                return_overflowing_tokens=False
            )
            inputs = {k: v.to(self.device) for k, v in inputs.items()}
            
            with torch.no_grad():
                text_features = self.model.get_text_features(**inputs)
                
            return text_features.cpu().numpy().flatten()
            
        except Exception as e:
            logging.error(f"텍스트 임베딩 생성 중 오류: {e}", exc_info=True)
            return None

    def _normalize_embeddings(self, image_emb: np.ndarray, text_emb: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """임베딩 벡터 정규화 및 결합"""
        try:
            # 정규화
            image_norm = image_emb / (np.linalg.norm(image_emb) + 1e-8)
            text_norm = text_emb / (np.linalg.norm(text_emb) + 1e-8)
            
            # 가중치 합산 (이미지 70%, 텍스트 30%)
            combined = 0.7 * image_norm + 0.3 * text_norm
            combined = combined / (np.linalg.norm(combined) + 1e-8)
            
            return image_norm, text_norm, combined
            
        except Exception as e:
            logging.error(f"임베딩 정규화 중 오류: {e}", exc_info=True)
            raise

    def generate_and_save_embeddings(self, item: WardrobeItem) -> bool:
        """
        워드로브 아이템에 대한 임베딩을 생성하고 저장합니다.
        
        Args:
            item (WardrobeItem): 임베딩을 생성할 워드로브 아이템
            
        Returns:
            bool: 임베딩 생성 및 저장 성공 여부
        """
        if not item or not hasattr(item, 'item_id'):
            logging.error("유효하지 않은 아이템입니다.")
            return False
            
        image_path = getattr(item, 'image_path', None)
        if not image_path or not os.path.exists(image_path):
            logging.warning(f"이미지 파일이 존재하지 않습니다. Item ID: {getattr(item, 'item_id', 'unknown')}, Path: {image_path}")
            return False
            
        try:
            # 1. 이미지 임베딩 생성
            image_embedding = self._generate_image_embedding(image_path)
            if image_embedding is None:
                logging.error(f"이미지 임베딩 생성 실패. Item ID: {item.item_id}")
                return False
                
            # 2. 메타데이터 기반 텍스트 임베딩 생성
            color = getattr(item, 'color', '')
            category = getattr(item, 'category', 'clothing')
            brand = getattr(item, 'brand', '')
            metadata_text = f"A {color} {category} from {brand}".strip()
            
            text_embedding = self._generate_text_embedding(metadata_text)
            if text_embedding is None:
                logging.error(f"텍스트 임베딩 생성 실패. Item ID: {item.item_id}")
                return False
                
            # 3. 임베딩 정규화 및 결합
            image_norm, text_norm, combined = self._normalize_embeddings(
                image_embedding, text_embedding
            )
            
            # 4. DB에 저장
            try:
                item.image_embedding = image_norm.tobytes()
                item.text_embedding = text_norm.tobytes()
                item.combined_embedding = combined.tobytes()
                
                db.session.add(item)
                db.session.commit()
                
                logging.info(f"임베딩 저장 완료: Item {item.item_id}")
                return True
                
            except Exception as db_error:
                db.session.rollback()
                logging.error(f"DB 저장 중 오류 (Item ID: {item.item_id}): {db_error}", exc_info=True)
                return False
                
        except Exception as e:
            logging.error(f"임베딩 생성 중 예상치 못한 오류 (Item ID: {getattr(item, 'item_id', 'unknown')}): {e}", 
                         exc_info=True)
            db.session.rollback()
            return False

    def process_all_items(self, batch_size: int = 32) -> dict:
        """
        모든 워드로브 아이템에 대해 임베딩을 일괄 처리합니다.
        
        Args:
            batch_size (int): 한 번에 처리할 배치 크기 (메모리 사용량 조절용)
            
        Returns:
            dict: 처리 결과 통계
                {
                    'total': 전체 아이템 수,
                    'success': 성공한 아이템 수,
                    'failed': 실패한 아이템 수,
                    'failed_ids': 실패한 아이템 ID 목록
                }
        """
        from sqlalchemy import func
        
        stats = {
            'total': 0,
            'success': 0,
            'failed': 0,
            'failed_ids': []
        }
        
        try:
            # 전체 아이템 수 조회
            total_items = db.session.query(func.count(WardrobeItem.item_id)).scalar()
            stats['total'] = total_items
            
            if total_items == 0:
                logging.info("처리할 아이템이 없습니다.")
                return stats
                
            logging.info(f"총 {total_items}개의 아이템에 대한 임베딩 처리를 시작합니다...")
            
            # 배치 단위로 처리
            offset = 0
            processed = 0
            
            while offset < total_items:
                # 배치 조회
                items = WardrobeItem.query.offset(offset).limit(batch_size).all()
                if not items:
                    break
                    
                for item in items:
                    try:
                        processed += 1
                        logging.info(f"[{processed}/{total_items}] 아이템 처리 중... (ID: {item.item_id})")
                        
                        # 임베딩 생성 및 저장
                        success = self.generate_and_save_embeddings(item)
                        if success:
                            stats['success'] += 1
                        else:
                            stats['failed'] += 1
                            stats['failed_ids'].append(item.item_id)
                            
                    except Exception as e:
                        error_msg = f"아이템 처리 중 오류 (ID: {getattr(item, 'item_id', 'unknown')}): {e}"
                        logging.error(error_msg, exc_info=True)
                        stats['failed'] += 1
                        if hasattr(item, 'item_id'):
                            stats['failed_ids'].append(item.item_id)
                            
                # 다음 배치로 이동
                offset += batch_size
                
            # 요약 로그 출력
            success_rate = (stats['success'] / total_items * 100) if total_items > 0 else 0
            logging.info(
                f"임베딩 처리 완료! "
                f"성공: {stats['success']}/{total_items} ({success_rate:.1f}%), "
                f"실패: {stats['failed']}"
            )
            
            if stats['failed'] > 0:
                logging.warning(f"실패한 아이템 ID 목록: {stats['failed_ids']}")
                
            return stats
            
        except Exception as e:
            error_msg = f"임베딩 일괄 처리 중 심각한 오류 발생: {e}"
            logging.error(error_msg, exc_info=True)
            raise RuntimeError(error_msg) from e
