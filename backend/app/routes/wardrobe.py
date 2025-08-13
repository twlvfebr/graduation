from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from ..models.models import db, WardrobeItem, User, Wardrobe
from ..services.recommendation_service import RecommendationService
import os
from werkzeug.utils import secure_filename
from PIL import Image
import uuid
from ..services.weather_service import get_weather_by_city

wardrobe_bp = Blueprint('wardrobe', __name__)
recommendation_service = RecommendationService()

# 이미지 업로드 설정
UPLOAD_FOLDER = 'uploads/wardrobe'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@wardrobe_bp.route('/items', methods=['POST'])
@jwt_required()
def add_item():
    current_user_id = get_jwt_identity()
    
    # 이미지 파일 확인
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    if not allowed_file(file.filename):
        return jsonify({'error': 'File type not allowed'}), 400
    
    # 이미지 저장
    filename = secure_filename(f"{uuid.uuid4()}_{file.filename}")
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    os.makedirs(UPLOAD_FOLDER, exist_ok=True)
    file.save(filepath)
    
    # 의류 아이템 감지
    detected_items = recommendation_service.detect_clothing_items(filepath)
    if not detected_items:
        return jsonify({'error': 'No clothing items detected'}), 400
    
    # CLIP 임베딩 계산
    embedding = recommendation_service.get_image_embedding(filepath)
    
    # 사용자의 기본 옷장 찾기 또는 생성
    user_wardrobe = Wardrobe.query.filter_by(user_id=current_user_id).first()
    if not user_wardrobe:
        user_wardrobe = Wardrobe(user_id=current_user_id)
        db.session.add(user_wardrobe)
        db.session.flush()  # wardrobe_id를 얻기 위해
    
    # 웹에서 접근 가능한 이미지 경로 생성
    web_image_path = f'/uploads/{filename}'
    
    # 새 의류 아이템 생성
    new_item = WardrobeItem(
        wardrobe_id=user_wardrobe.wardrobe_id,
        name=request.form.get('name', ''),
        category=request.form.get('category', ''),
        color=request.form.get('color', ''),
        brand=request.form.get('brand', ''),
        image_path=web_image_path
    )
    
    try:
        db.session.add(new_item)
        db.session.commit()
        
        return jsonify({
            'message': 'Item added successfully',
            'item': {
                'id': new_item.item_id,
                'name': new_item.name,
                'category': new_item.category,
                'image_path': new_item.image_path,
                'color': new_item.color,
                'brand': new_item.brand
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@wardrobe_bp.route('/items', methods=['GET'])
@jwt_required()
def get_items():
    current_user_id = get_jwt_identity()
    category = request.args.get('category')
    
    # 사용자의 옷장 찾기
    user_wardrobe = Wardrobe.query.filter_by(user_id=current_user_id).first()
    if not user_wardrobe:
        return jsonify({'items': []}), 200
    
    # 옷장의 아이템들 조회
    query = WardrobeItem.query.filter_by(wardrobe_id=user_wardrobe.wardrobe_id)
    
    if category:
        query = query.filter_by(category=category)
    
    items = query.all()
    
    return jsonify({
        'items': [{
            'id': item.item_id,
            'name': item.name,
            'category': item.category,
            'image_path': item.image_path,
            'color': item.color,
            'brand': item.brand,
            'created_at': item.created_at.isoformat() if item.created_at else None
        } for item in items]
    }), 200

@wardrobe_bp.route('/items/<int:item_id>', methods=['PUT'])
@jwt_required()
def update_item(item_id):
    current_user_id = get_jwt_identity()
    item = WardrobeItem.query.filter_by(id=item_id, user_id=current_user_id).first()
    
    if not item:
        return jsonify({'error': 'Item not found'}), 404
    
    data = request.get_json()
    
    # 업데이트 가능한 필드들
    if 'name' in data:
        item.name = data['name']
    if 'category' in data:
        item.category = data['category']
    if 'subcategory' in data:
        item.subcategory = data['subcategory']
    if 'color' in data:
        item.color = data['color']
    if 'brand' in data:
        item.brand = data['brand']
    
    try:
        db.session.commit()
        return jsonify({
            'message': 'Item updated successfully',
            'item': {
                'id': item.id,
                'name': item.name,
                'category': item.category,
                'subcategory': item.subcategory,
                'image_path': item.image_path,
                'color': item.color,
                'brand': item.brand
            }
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@wardrobe_bp.route('/items/<int:item_id>', methods=['DELETE'])
@jwt_required()
def delete_item(item_id):
    current_user_id = get_jwt_identity()
    item = WardrobeItem.query.filter_by(id=item_id, user_id=current_user_id).first()
    
    if not item:
        return jsonify({'error': 'Item not found'}), 404
    
    try:
        # 이미지 파일 삭제
        if os.path.exists(item.image_path):
            os.remove(item.image_path)
        
        db.session.delete(item)
        db.session.commit()
        
        return jsonify({'message': 'Item deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@wardrobe_bp.route('/weather', methods=['GET'])
def get_weather():
    city = request.args.get('city', 'Seoul')
    try:
        print("==== 날씨 API 진입 ====")
        weather = get_weather_by_city(city)
        print("==== 날씨 API 결과 ====", weather)
        if weather:
            return jsonify(weather)
        else:
            print("==== 날씨 정보 없음 ====")
            return jsonify({'error': '날씨 정보를 가져올 수 없습니다.'}), 400
    except Exception as e:
        print("==== 예외 발생 ====")
        print(e)
        # 에러 메시지를 JSON으로 강제 반환
        return jsonify({'error': str(e), 'type': str(type(e))}), 500 