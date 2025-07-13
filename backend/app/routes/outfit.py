from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from ..models.models import db, Outfit, WardrobeItem, User
from ..services.recommendation_service import RecommendationService
import requests
from datetime import datetime

outfit_bp = Blueprint('outfit', __name__)
recommendation_service = RecommendationService()

def get_weather_data(latitude, longitude):
    """날씨 API에서 날씨 정보를 가져옵니다."""
    # OpenWeatherMap API 사용 예시
    API_KEY = "YOUR_API_KEY"  # 실제 API 키로 교체 필요
    url = f"http://api.openweathermap.org/data/2.5/weather?lat={latitude}&lon={longitude}&appid={API_KEY}&units=metric"
    
    try:
        response = requests.get(url)
        data = response.json()
        return {
            'temperature': data['main']['temp'],
            'weather': data['weather'][0]['main'],
            'humidity': data['main']['humidity']
        }
    except Exception as e:
        return None

@outfit_bp.route('/recommend', methods=['POST'])
@jwt_required()
def recommend_outfit():
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    data = request.get_json()
    latitude = data.get('latitude')
    longitude = data.get('longitude')
    
    if not latitude or not longitude:
        return jsonify({'error': 'Location information is required'}), 400
    
    # 날씨 정보 가져오기
    weather_data = get_weather_data(latitude, longitude)
    if not weather_data:
        return jsonify({'error': 'Failed to fetch weather data'}), 500
    
    # 사용자의 옷장 아이템 가져오기
    wardrobe_items = WardrobeItem.query.filter_by(user_id=current_user_id).all()
    wardrobe_items_data = [{
        'id': item.id,
        'category': item.category,
        'subcategory': item.subcategory,
        'embedding': item.embedding
    } for item in wardrobe_items]
    
    # 코디 추천
    recommended_outfit = recommendation_service.recommend_outfit(
        user_id=current_user_id,
        weather_data=weather_data,
        style_preferences=user.preferred_styles,
        wardrobe_items=wardrobe_items_data
    )
    
    # 추천된 코디 저장
    new_outfit = Outfit(
        user_id=current_user_id,
        name=f"Recommended Outfit {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        items=recommended_outfit['items'],
        style_tags=recommended_outfit['style_tags'],
        created_at=recommended_outfit['created_at']
    )
    
    try:
        db.session.add(new_outfit)
        db.session.commit()
        
        return jsonify({
            'message': 'Outfit recommended successfully',
            'outfit': {
                'id': new_outfit.id,
                'name': new_outfit.name,
                'items': new_outfit.items,
                'style_tags': new_outfit.style_tags,
                'weather_data': weather_data,
                'created_at': new_outfit.created_at.isoformat()
            }
        }), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@outfit_bp.route('/outfits', methods=['GET'])
@jwt_required()
def get_outfits():
    current_user_id = get_jwt_identity()
    outfits = Outfit.query.filter_by(user_id=current_user_id).order_by(Outfit.created_at.desc()).all()
    
    return jsonify({
        'outfits': [{
            'id': outfit.id,
            'name': outfit.name,
            'items': outfit.items,
            'style_tags': outfit.style_tags,
            'created_at': outfit.created_at.isoformat()
        } for outfit in outfits]
    }), 200

@outfit_bp.route('/outfits/<int:outfit_id>', methods=['GET'])
@jwt_required()
def get_outfit(outfit_id):
    current_user_id = get_jwt_identity()
    outfit = Outfit.query.filter_by(id=outfit_id, user_id=current_user_id).first()
    
    if not outfit:
        return jsonify({'error': 'Outfit not found'}), 404
    
    return jsonify({
        'id': outfit.id,
        'name': outfit.name,
        'items': outfit.items,
        'style_tags': outfit.style_tags,
        'created_at': outfit.created_at.isoformat()
    }), 200

@outfit_bp.route('/outfits/<int:outfit_id>', methods=['DELETE'])
@jwt_required()
def delete_outfit(outfit_id):
    current_user_id = get_jwt_identity()
    outfit = Outfit.query.filter_by(id=outfit_id, user_id=current_user_id).first()
    
    if not outfit:
        return jsonify({'error': 'Outfit not found'}), 404
    
    try:
        db.session.delete(outfit)
        db.session.commit()
        return jsonify({'message': 'Outfit deleted successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500 