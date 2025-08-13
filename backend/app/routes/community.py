from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from ..models.models import db, CommunityPost, Comment, Like, Hashtag, PostHashtag, User
import os
import re

community_bp = Blueprint('community', __name__)

def extract_hashtags(text):
    if not text:
        return []
    return re.findall(r'#(\w+)', text)

@community_bp.route('/post', methods=['POST'])
@jwt_required()
def create_post():
    data = request.form
    user_id = get_jwt_identity()
    description = data.get('description')
    image = request.files.get('image')
    image_path = None
    if image:
        filename = image.filename or f'image_{user_id}.jpg'
        static_dir = os.path.join(os.getcwd(), 'static')
        if not os.path.exists(static_dir):
            os.makedirs(static_dir)
        image_path = os.path.join('static', filename)
        image.save(os.path.join(os.getcwd(), image_path))
    hashtags = extract_hashtags(description)
    hashtag_str = ','.join(hashtags)
    new_post = CommunityPost(
        user_id=user_id,
        description=description,
        image_path=image_path,
        hashtag=hashtag_str
    )
    db.session.add(new_post)
    db.session.commit()
    return jsonify({'message': '게시글 등록', 'id': new_post.post_id}), 201

@community_bp.route('/posts', methods=['GET'])
@jwt_required()
def get_posts():
    query = request.args.get('query', '').strip()
    posts_query = CommunityPost.query
    if query:
        posts_query = posts_query.filter(
            (CommunityPost.description.ilike(f'%{query}%')) |
            (CommunityPost.hashtag.ilike(f'%{query}%'))
        )
    posts = posts_query.order_by(CommunityPost.created_at.desc()).all()
    post_list = []
    for post in posts:
        post_list.append({
            'id': post.post_id,
            'user_id': post.user_id,
            'username': post.user.username if post.user else None,
            'description': post.description,
            'image': post.image_path,
            'created_at': post.created_at.isoformat() if post.created_at else None,
            'hashtags': post.hashtag.split(',') if post.hashtag else []
        })
    return jsonify({'posts': post_list}), 200

# 게시글 수정
@community_bp.route('/post/<int:post_id>', methods=['PUT'])
@jwt_required()
def update_post(post_id):
    user_id = get_jwt_identity()
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글이 존재하지 않습니다.'}), 404
    if post.user_id != int(user_id):
        return jsonify({'message': '권한이 없습니다.'}), 403
    data = request.get_json()
    post.description = data.get('description', post.description)
    hashtags = extract_hashtags(post.description)
    post.hashtag = ','.join(hashtags)
    db.session.commit()
    return jsonify({'message': '게시글이 수정되었습니다.'}), 200

# 게시글 삭제
@community_bp.route('/post/<int:post_id>', methods=['DELETE'])
@jwt_required()
def delete_post(post_id):
    user_id = get_jwt_identity()
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글이 존재하지 않습니다.'}), 404
    if post.user_id != int(user_id):
        return jsonify({'message': '권한이 없습니다.'}), 403
    db.session.delete(post)
    db.session.commit()
    return jsonify({'message': '게시글이 삭제되었습니다.'}), 200

@community_bp.route('/like', methods=['POST'])
@jwt_required()
def like_post():
    user_id = get_jwt_identity()
    data = request.get_json()
    post_id = data.get('post_id')
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글이 존재하지 않습니다.'}), 404
    like = Like.query.filter_by(user_id=user_id, post_id=post_id).first()
    if like:
        db.session.delete(like)
        db.session.commit()
        liked = False
    else:
        new_like = Like(user_id=user_id, post_id=post_id)
        db.session.add(new_like)
        db.session.commit()
        liked = True
    like_count = Like.query.filter_by(post_id=post_id).count()
    return jsonify({'liked': liked, 'like_count': like_count}), 200

@community_bp.route('/comment', methods=['POST'])
@jwt_required()
def add_comment():
    user_id = get_jwt_identity()
    data = request.get_json()
    post_id = data.get('post_id')
    content = data.get('content')
    if not content:
        return jsonify({'message': '댓글 내용을 입력하세요.'}), 400
    post = CommunityPost.query.get(post_id)
    if not post:
        return jsonify({'message': '게시글이 존재하지 않습니다.'}), 404
    new_comment = Comment(user_id=user_id, post_id=post_id, content=content)
    db.session.add(new_comment)
    db.session.commit()
    comment_count = Comment.query.filter_by(post_id=post_id).count()
    return jsonify({'message': '댓글 등록 완료', 'comment_count': comment_count}), 201

# 댓글 수정
@community_bp.route('/comment/<int:comment_id>', methods=['PUT'])
@jwt_required()
def update_comment(comment_id):
    user_id = get_jwt_identity()
    comment = Comment.query.get(comment_id)
    if not comment:
        return jsonify({'message': '댓글이 존재하지 않습니다.'}), 404
    if comment.user_id != int(user_id):
        return jsonify({'message': '권한이 없습니다.'}), 403
    data = request.get_json()
    comment.content = data.get('content', comment.content)
    db.session.commit()
    return jsonify({'message': '댓글이 수정되었습니다.'}), 200

# 댓글 삭제
@community_bp.route('/comment/<int:comment_id>', methods=['DELETE'])
@jwt_required()
def delete_comment(comment_id):
    user_id = get_jwt_identity()
    comment = Comment.query.get(comment_id)
    if not comment:
        return jsonify({'message': '댓글이 존재하지 않습니다.'}), 404
    if comment.user_id != int(user_id):
        return jsonify({'message': '권한이 없습니다.'}), 403
    db.session.delete(comment)
    db.session.commit()
    return jsonify({'message': '댓글이 삭제되었습니다.'}), 200

@community_bp.route('/comments/<int:post_id>', methods=['GET'])
@jwt_required()
def get_comments(post_id):
    comments = Comment.query.filter_by(post_id=post_id).order_by(Comment.created_at.asc()).all()
    comment_list = []
    for c in comments:
        user = User.query.get(c.user_id)
        comment_list.append({
            'id': c.comment_id,
            'user_id': c.user_id,
            'username': user.username if user else None,
            'content': c.content,
            'created_at': c.created_at.isoformat() if c.created_at else None
        })
    return jsonify({'comments': comment_list, 'comment_count': len(comment_list)}), 200

# 내가 쓴 글 목록
@community_bp.route('/my_posts', methods=['GET'])
@jwt_required()
def my_posts():
    user_id = get_jwt_identity()
    posts = CommunityPost.query.filter_by(user_id=user_id).order_by(CommunityPost.created_at.desc()).all()
    post_list = []
    for post in posts:
        post_list.append({
            'id': post.post_id,
            'user_id': post.user_id,
            'username': post.user.username if post.user else None,
            'description': post.description,
            'image': post.image_path,
            'created_at': post.created_at.isoformat() if post.created_at else None,
            'hashtags': post.hashtag.split(',') if post.hashtag else []
        })
    return jsonify({'posts': post_list}), 200

# 내가 좋아요한 글 목록
@community_bp.route('/my_likes', methods=['GET'])
@jwt_required()
def my_likes():
    user_id = get_jwt_identity()
    likes = Like.query.filter_by(user_id=user_id).all()
    post_ids = [like.post_id for like in likes if like.post_id]
    posts = CommunityPost.query.filter(CommunityPost.post_id.in_(post_ids)).order_by(CommunityPost.created_at.desc()).all()
    post_list = []
    for post in posts:
        post_list.append({
            'id': post.post_id,
            'user_id': post.user_id,
            'username': post.user.username if post.user else None,
            'description': post.description,
            'image': post.image_path,
            'created_at': post.created_at.isoformat() if post.created_at else None,
            'hashtags': post.hashtag.split(',') if post.hashtag else []
        })
    return jsonify({'posts': post_list}), 200

# 내가 쓴 댓글 목록
@community_bp.route('/my_comments', methods=['GET'])
@jwt_required()
def my_comments():
    user_id = get_jwt_identity()
    comments = Comment.query.filter_by(user_id=user_id).order_by(Comment.created_at.desc()).all()
    comment_list = []
    for c in comments:
        post = CommunityPost.query.get(c.post_id)
        comment_list.append({
            'comment_id': c.comment_id,
            'post_id': c.post_id,
            'post_description': post.description if post else '',
            'content': c.content,
            'created_at': c.created_at.isoformat() if c.created_at else None
        })
    return jsonify({'comments': comment_list}), 200

# 내가 올린 게시글 개수
@community_bp.route('/my_post_count', methods=['GET'])
@jwt_required()
def my_post_count():
    user_id = get_jwt_identity()
    count = CommunityPost.query.filter_by(user_id=user_id).count()
    return jsonify({'post_count': count}), 200

# 내가 받은 좋아요 총합
@community_bp.route('/my_like_count', methods=['GET'])
@jwt_required()
def my_like_count():
    user_id = get_jwt_identity()
    posts = CommunityPost.query.filter_by(user_id=user_id).all()
    post_ids = [p.post_id for p in posts]
    like_count = 0
    if post_ids:
        like_count = Like.query.filter(Like.post_id.in_(post_ids)).count()
    return jsonify({'like_count': like_count}), 200

# 내가 올린 게시글에 누가 좋아요를 눌렀는지 상세 목록
@community_bp.route('/my_like_details', methods=['GET'])
@jwt_required()
def my_like_details():
    user_id = get_jwt_identity()
    posts = CommunityPost.query.filter_by(user_id=user_id).all()
    post_ids = [p.post_id for p in posts]
    like_details = []
    if post_ids:
        likes = Like.query.filter(Like.post_id.in_(post_ids)).all()
        for like in likes:
            liker = User.query.get(like.user_id)
            post = CommunityPost.query.get(like.post_id)
            like_details.append({
                'liker_id': liker.id if liker else None,
                'liker_username': liker.username if liker else None,
                'liker_profile_image': None,  # 프로필 이미지 필드가 있다면 넣기
                'post_id': post.post_id if post else None,
                'post_image': post.image_path if post else None
            })
    return jsonify({'like_details': like_details, 'like_count': len(like_details)}), 200 