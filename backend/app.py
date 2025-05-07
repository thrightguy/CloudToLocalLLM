from flask import Flask, jsonify, request, session
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import os

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'your-secret-key-here')  # Change this in production
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(120), nullable=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Create tables
with app.app_context():
    db.create_all()
    # Create a default user if none exists
    if not User.query.filter_by(username='admin').first():
        user = User(username='admin')
        user.set_password('admin')  # Change this password in production
        db.session.add(user)
        db.session.commit()

@app.route('/api/health')
def health_check():
    return jsonify({"status": "healthy"})

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    user = User.query.filter_by(username=username).first()
    if user and user.check_password(password):
        login_user(user)
        return jsonify({"status": "success", "message": "Logged in successfully"})
    return jsonify({"status": "error", "message": "Invalid username or password"}), 401

@app.route('/api/logout', methods=['POST'])
@login_required
def logout():
    logout_user()
    return jsonify({"status": "success", "message": "Logged out successfully"})

@app.route('/api/user', methods=['GET'])
@login_required
def get_user():
    return jsonify({
        "id": current_user.id,
        "username": current_user.username
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)