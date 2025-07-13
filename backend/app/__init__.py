from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from .models.models import db
from datetime import timedelta
import os

def create_app():
    app = Flask(__name__)
    
    # 환경 변수 설정
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev')
    app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://root:qkrdudwns1@localhost:3306/fashion_db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret-key')
    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=1)
    
    # 확장 초기화
    CORS(app)
    JWTManager(app)
    db.init_app(app)
    migrate = Migrate(app, db)
    
    # 블루프린트 등록
    from .routes.auth import auth_bp
    from .routes.wardrobe import wardrobe_bp
    from .routes.outfit import outfit_bp
    from .routes.community import community_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(wardrobe_bp, url_prefix='/api/wardrobe')
    app.register_blueprint(outfit_bp, url_prefix='/api/outfit')
    app.register_blueprint(community_bp, url_prefix='/api/community')

    # 기본 라우트 추가
    @app.route('/')
    def index():
        return 'Hello, Flask!'
    
    return app 