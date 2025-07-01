# app/routes/__init__.py

from flask import Blueprint
from .upload_routes import bp as upload_bp

# 创建一个主蓝图来组织所有子路由
main_routes = Blueprint('main_routes', __name__)

# 注册上传相关的路由
main_routes.register_blueprint(upload_bp)