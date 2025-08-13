from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

# User & Profile
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password = db.Column(db.String(128), nullable=False)
    gender = db.Column(db.String(10))
    signup_date = db.Column(db.DateTime, default=datetime.utcnow)
    birth = db.Column(db.Date)
    profile_image = db.Column(db.String(255))  # 프로필 이미지 경로 추가
    
    profile = db.relationship('Profile', uselist=False, backref='user')
    wardrobes = db.relationship('Wardrobe', backref='user', cascade='all, delete-orphan')
    recommendations = db.relationship('Recommendation', backref='user', cascade='all, delete-orphan')
    posts = db.relationship('CommunityPost', backref='user', cascade='all, delete-orphan')
    likes = db.relationship('Like', backref='user', cascade='all, delete-orphan')
    comments = db.relationship('Comment', backref='user', cascade='all, delete-orphan')

    def set_password(self, password):
        self.password = generate_password_hash(password, method='pbkdf2:sha256')

    def check_password(self, password):
        return check_password_hash(self.password, password)

class Profile(db.Model):
    __tablename__ = 'profile'
    profile_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True)
    wardrobe_count = db.Column(db.Integer, default=0)
    post_count = db.Column(db.Integer, default=0)
    total_recommend_count = db.Column(db.Integer, default=0)

# Style & PreferredStyle
class Style(db.Model):
    __tablename__ = 'style'
    style_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50), unique=True)
    wardrobes = db.relationship('WardrobeStyle', backref='style', cascade='all, delete-orphan')
    preferred_users = db.relationship('PreferredStyle', backref='style', cascade='all, delete-orphan')

class PreferredStyle(db.Model):
    __tablename__ = 'preferred_style'
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), primary_key=True)
    style_id = db.Column(db.Integer, db.ForeignKey('style.style_id'), primary_key=True)

# Wardrobe & M:N 관계
class Wardrobe(db.Model):
    __tablename__ = 'wardrobe'
    wardrobe_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    image_path = db.Column(db.String(255))
    upload_date = db.Column(db.DateTime, default=datetime.utcnow)
    
    styles = db.relationship('WardrobeStyle', backref='wardrobe', cascade='all, delete-orphan')
    colors = db.relationship('WardrobeColor', backref='wardrobe', cascade='all, delete-orphan')
    seasons = db.relationship('WardrobeSeason', backref='wardrobe', cascade='all, delete-orphan')
    recommendations = db.relationship('Recommendation', backref='wardrobe', cascade='all, delete-orphan')

class WardrobeStyle(db.Model):
    __tablename__ = 'wardrobe_style'
    wardrobe_id = db.Column(db.Integer, db.ForeignKey('wardrobe.wardrobe_id'), primary_key=True)
    style_id = db.Column(db.Integer, db.ForeignKey('style.style_id'), primary_key=True)

class Color(db.Model):
    __tablename__ = 'color'
    color_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(30), unique=True)
    wardrobes = db.relationship('WardrobeColor', backref='color', cascade='all, delete-orphan')

class WardrobeColor(db.Model):
    __tablename__ = 'wardrobe_color'
    wardrobe_id = db.Column(db.Integer, db.ForeignKey('wardrobe.wardrobe_id'), primary_key=True)
    color_id = db.Column(db.Integer, db.ForeignKey('color.color_id'), primary_key=True)

class Season(db.Model):
    __tablename__ = 'season'
    season_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(30), unique=True)
    wardrobes = db.relationship('WardrobeSeason', backref='season', cascade='all, delete-orphan')

class WardrobeSeason(db.Model):
    __tablename__ = 'wardrobe_season'
    wardrobe_id = db.Column(db.Integer, db.ForeignKey('wardrobe.wardrobe_id'), primary_key=True)
    season_id = db.Column(db.Integer, db.ForeignKey('season.season_id'), primary_key=True)

# Recommendation & Weather
class Recommendation(db.Model):
    __tablename__ = 'recommendation'
    recommendation_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    wardrobe_id = db.Column(db.Integer, db.ForeignKey('wardrobe.wardrobe_id'))
    weather_id = db.Column(db.Integer, db.ForeignKey('weather.weather_id'))
    date = db.Column(db.DateTime, default=datetime.utcnow)

class Weather(db.Model):
    __tablename__ = 'weather'
    weather_id = db.Column(db.Integer, primary_key=True)
    city_name = db.Column(db.String(50))
    temperature = db.Column(db.Float)
    description = db.Column(db.String(100))
    recommendations = db.relationship('Recommendation', backref='weather', cascade='all, delete-orphan')

# CommunityPost, Like, Comment, Hashtag
class CommunityPost(db.Model):
    __tablename__ = 'community_post'
    post_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    image_path = db.Column(db.String(255))
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    hashtag = db.Column(db.String(255))
    likes = db.relationship('Like', backref='community_post', cascade='all, delete-orphan')
    comments = db.relationship('Comment', backref='community_post', cascade='all, delete-orphan')
    post_hashtags = db.relationship('PostHashtag', backref='community_post', cascade='all, delete-orphan')

class Like(db.Model):
    __tablename__ = 'like'
    like_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    post_id = db.Column(db.Integer, db.ForeignKey('community_post.post_id'))
    outfit_id = db.Column(db.Integer, db.ForeignKey('outfits.id'))

class Comment(db.Model):
    __tablename__ = 'comment'
    comment_id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    post_id = db.Column(db.Integer, db.ForeignKey('community_post.post_id'))
    outfit_id = db.Column(db.Integer, db.ForeignKey('outfits.id'))
    content = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Hashtag(db.Model):
    __tablename__ = 'hashtag'
    hashtag_id = db.Column(db.Integer, primary_key=True)
    tag_text = db.Column(db.String(50), unique=True)
    post_hashtags = db.relationship('PostHashtag', backref='hashtag', cascade='all, delete-orphan')

class PostHashtag(db.Model):
    __tablename__ = 'post_hashtag'
    post_id = db.Column(db.Integer, db.ForeignKey('community_post.post_id'), primary_key=True)
    hashtag_id = db.Column(db.Integer, db.ForeignKey('hashtag.hashtag_id'), primary_key=True)

class Clothing(db.Model):
    __tablename__ = 'clothes'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    category = db.Column(db.String(50), nullable=False)  # 상의, 하의, 아우터, 신발 등
    subcategory = db.Column(db.String(50))  # 티셔츠, 셔츠, 청바지 등
    color = db.Column(db.String(50))
    brand = db.Column(db.String(100))
    image_url = db.Column(db.String(500))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 관계 설정
    outfit_items = db.relationship('OutfitItem', backref='clothing', lazy=True)

class Outfit(db.Model):
    __tablename__ = 'outfits'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    image_url = db.Column(db.String(500))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # 관계 설정
    items = db.relationship('OutfitItem', backref='outfit', lazy=True)
    likes = db.relationship('Like', backref='outfit', lazy=True)
    comments = db.relationship('Comment', backref='outfit', lazy=True)

class OutfitItem(db.Model):
    __tablename__ = 'outfit_items'
    
    id = db.Column(db.Integer, primary_key=True)
    outfit_id = db.Column(db.Integer, db.ForeignKey('outfits.id'), nullable=False)
    clothing_id = db.Column(db.Integer, db.ForeignKey('clothes.id'), nullable=False)
    position = db.Column(db.String(50))  # 상의, 하의, 아우터, 신발 등 

class WardrobeItem(db.Model):
    __tablename__ = 'wardrobe_item'
    item_id = db.Column(db.Integer, primary_key=True)
    wardrobe_id = db.Column(db.Integer, db.ForeignKey('wardrobe.wardrobe_id'))
    name = db.Column(db.String(100), nullable=False)
    category = db.Column(db.String(50))
    color = db.Column(db.String(30))
    brand = db.Column(db.String(50))
    image_path = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    wardrobe = db.relationship('Wardrobe', backref='items') 