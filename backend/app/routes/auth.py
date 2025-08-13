from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity
from ..models.models import db, User
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
import os
import uuid

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    
    # 필수 필드 검증
    required_fields = ['username', 'password']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'{field} is required'}), 400
    
    # 사용자명 중복 검사
    if User.query.filter_by(username=data['username']).first():
        return jsonify({'error': 'Username already taken'}), 400
    
    # 새 사용자 생성
    new_user = User(
        username=data['username'],
        gender=data.get('gender'),
        birth=data.get('birth')
    )
    new_user.set_password(data['password'])
    
    try:
        db.session.add(new_user)
        db.session.commit()
        
        # 회원가입 성공 시 토큰 생성
        access_token = create_access_token(identity=str(new_user.id))
        return jsonify({
            'message': 'User registered successfully',
            'access_token': access_token,
            'user': {
                'id': new_user.id,
                'username': new_user.username
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    
    if not data or not data.get('username') or not data.get('password'):
        return jsonify({'error': 'Username and password are required'}), 400
    
    user = User.query.filter_by(username=data['username']).first()
    
    if not user or not user.check_password(data['password']):
        return jsonify({'error': 'Invalid username or password'}), 401
    
    access_token = create_access_token(identity=str(user.id))
    return jsonify({
        'access_token': access_token,
        'user': {
            'id': user.id,
            'username': user.username
        }
    }), 200

@auth_bp.route('/profile', methods=['GET'])
@jwt_required()
def get_profile():
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404
    
    return jsonify({
        'id': user.id,
        'username': user.username,
        'gender': user.gender,
        'birth': user.birth.isoformat() if user.birth else None,
        'preferred_styles': getattr(user, 'preferred_styles', None),
        'created_at': user.created_at.isoformat() if hasattr(user, 'created_at') else None,
        'profile_image': user.profile_image
    }), 200

@auth_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    current_user_id = get_jwt_identity()
    user = User.query.get(current_user_id)
    
    if not user:
        return jsonify({'error': 'User not found'}), 404

    # 멀티파트로 받는 경우 지원
    if request.content_type and request.content_type.startswith('multipart/form-data'):
        data = request.form
        file = request.files.get('profile_image')
    else:
        data = request.get_json() or {}
        file = None

    # 업데이트 가능한 필드들
    if 'username' in data:
        new_username = data['username']
        if new_username != user.username:
            existing_user = User.query.filter_by(username=new_username).first()
            if existing_user:
                return jsonify({'error': 'Username already taken'}), 400
            user.username = new_username
    if 'preferred_styles' in data:
        user.preferred_styles = data['preferred_styles']
    if 'password' in data:
        user.set_password(data['password'])
    if file:
        ext = (file.filename.rsplit('.', 1)[-1].lower() if file.filename and '.' in file.filename else 'jpg')
        filename = f'profile_{user.id}_{uuid.uuid4().hex}.{ext}'
        static_dir = os.path.join(os.getcwd(), 'static')
        if not os.path.exists(static_dir):
            os.makedirs(static_dir)
        save_path = os.path.join(static_dir, filename)
        file.save(save_path)
        user.profile_image = f'/static/{filename}'
    try:
        db.session.commit()
        return jsonify({
            'message': 'Profile updated successfully',
            'user': {
                'id': user.id,
                'username': user.username,
                'preferred_styles': getattr(user, 'preferred_styles', None),
                'profile_image': user.profile_image
            }
        }), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500 