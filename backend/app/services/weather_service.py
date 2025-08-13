import requests
import os
from flask import jsonify

def get_weather_by_city(city_name):
    api_key = os.environ.get('OPENWEATHER_API_KEY')
    if not api_key:
        raise Exception('OPENWEATHER_API_KEY 환경변수가 설정되어 있지 않습니다.')
    url = f'http://api.openweathermap.org/data/2.5/weather?q={city_name}&appid={api_key}&units=metric'
    try:
        response = requests.get(url)
        if response.status_code != 200:
            return None
        data = response.json()
        return {
            'city': data['name'],
            'temp': data['main']['temp'],
            'weather': data['weather'][0]['main'],
            'description': data['weather'][0]['description'],
        }
    except Exception as e:
        import traceback
        print("==== 예외 발생 ====")
        print(e)
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
