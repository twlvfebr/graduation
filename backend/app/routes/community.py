from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from ..models.models import db, CommunityPost, Outfit, Like, Comment, User
from datetime import datetime

community_bp = Blueprint('community', __name__)

@community_bp.route('/posts', methods=['POST'])
@jwt_required()
def create_post():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    if not data.get('content') and not data.get('outfit_id'):
        return jsonify({'error': 'Content or outfit_id is required'}), 400
    
    # outfit_id가 제공된 경우 해당 outfit이 존재하는지 확인
    outfit = None
    if data.get('outfit_id'):
        outfit = Outfit.query.get(data['outfit_id'])
        if not outfit:
            return jsonify({'error': 'Outfit not found'}), 404
    
    new_post = CommunityPost(
        user_id=current_user_id,
        outfit_id=data.get('outfit_id'),
        content=data.get('content', '')
    )
    
    try:
        db.session.add(new_post)
        db.session.commit()
        
        return jsonify({
            'message': 'Post created successfully',
            'post': {
                'id': new_post.id,
                'user_id': new_post.user_id,
                'outfit_id': new_post.outfit_id,
                'content': new_post.content,
                'created_at': new_post.created_at.isoformat()
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@community_bp.route('/posts', methods=['GET'])
@jwt_required()
def get_posts():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 10, type=int)
    
    posts = CommunityPost.query.order_by(CommunityPost.created_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False)
    
    return jsonify({
        'posts': [{
            'id': post.id,
            'user': {
                'id': post.author.id,
                'username': post.author.username
            },
            'outfit': {
                'id': post.outfit.id,
                'name': post.outfit.name,
                'items': post.outfit.items,
                'style_tags': post.outfit.style_tags
            } if post.outfit else None,
            'content': post.content,
            'likes_count': len(post.likes),
            'comments_count': len(post.comments),
            'created_at': post.created_at.isoformat()
        } for post in posts.items],
        'total': posts.total,
        'pages': posts.pages,
        'current_page': posts.page
    }), 200

@community_bp.route('/posts/<int:post_id>', methods=['GET'])
@jwt_required()
def get_post(post_id):
    post = CommunityPost.query.get(post_id)
    
    if not post:
        return jsonify({'error': 'Post not found'}), 404
    
    return jsonify({
        'id': post.id,
        'user': {
            'id': post.author.id,
            'username': post.author.username
        },
        'outfit': {
            'id': post.outfit.id,
            'name': post.outfit.name,
            'items': post.outfit.items,
            'style_tags': post.outfit.style_tags
        } if post.outfit else None,
        'content': post.content,
        'likes': [{
            'user_id': like.user_id,
            'username': like.user.username
        } for like in post.likes],
        'comments': [{
            'id': comment.id,
            'user_id': comment.user_id,
            'username': comment.user.username,
            'content': comment.content,
            'created_at': comment.created_at.isoformat()
        } for comment in post.comments],
        'created_at': post.created_at.isoformat()
    }), 200

@community_bp.route('/posts/<int:post_id>/like', methods=['POST'])
@jwt_required()
def like_post(post_id):
    current_user_id = get_jwt_identity()
    post = CommunityPost.query.get(post_id)
    
    if not post:
        return jsonify({'error': 'Post not found'}), 404
    
    # 이미 좋아요를 눌렀는지 확인
    existing_like = Like.query.filter_by(
        user_id=current_user_id, post_id=post_id).first()
    
    if existing_like:
        return jsonify({'error': 'Already liked this post'}), 400
    
    new_like = Like(user_id=current_user_id, post_id=post_id)
    
    try:
        db.session.add(new_like)
        db.session.commit()
        return jsonify({'message': 'Post liked successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@community_bp.route('/posts/<int:post_id>/unlike', methods=['POST'])
@jwt_required()
def unlike_post(post_id):
    current_user_id = get_jwt_identity()
    like = Like.query.filter_by(
        user_id=current_user_id, post_id=post_id).first()
    
    if not like:
        return jsonify({'error': 'Like not found'}), 404
    
    try:
        db.session.delete(like)
        db.session.commit()
        return jsonify({'message': 'Post unliked successfully'}), 200
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@community_bp.route('/posts/<int:post_id>/comments', methods=['POST'])
@jwt_required()
def add_comment(post_id):
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    if not data.get('content'):
        return jsonify({'error': 'Content is required'}), 400
    
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'error': 'Post not found'}), 404
    
    new_comment = Comment(
        user_id=current_user_id,
        post_id=post_id,
        content=data['content']
    )
    
    try:
        db.session.add(new_comment)
        db.session.commit()
        
        return jsonify({
            'message': 'Comment added successfully',
            'comment': {
                'id': new_comment.id,
                'user_id': new_comment.user_id,
                'username': new_comment.user.username,
                'content': new_comment.content,
                'created_at': new_comment.created_at.isoformat()
            }
        }), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@community_bp.route('/posts/<int:post_id>/comments', methods=['GET'])
@jwt_required()
def get_comments(post_id):
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'error': 'Post not found'}), 404
    
    comments = Comment.query.filter_by(post_id=post_id).order_by(Comment.created_at.asc()).all()
    
    return jsonify({
        'comments': [{
            'id': comment.id,
            'user_id': comment.user_id,
            'username': comment.user.username,
            'content': comment.content,
            'created_at': comment.created_at.isoformat()
        } for comment in comments]
    }), 200 