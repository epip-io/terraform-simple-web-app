import os
from flask import Flask
app = Flask(__name__)

@app.route('/')
def main():
  return 'Welcome to the world!'

@app.route('/status')
def status():
  return 'All is well with the world'

if __name__ == '__main__':
  app.run(host='0.0.0.0', port=80)
