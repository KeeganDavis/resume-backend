import os

from flask import Flask
from google.cloud import datastore
from flask_cors import CORS

app = Flask(__name__)
CORS(app, origins=["https://keeganrdavis.com"])
client = datastore.Client(project='', database='')

@app.route("/")
def create_or_update_entity():
    kind = "Count"
    name = 'viewer_count'
    key = client.key(kind, name)

    with client.transaction():
        entity = client.get(key)
        if not entity:
            entity = datastore.Entity(key=key)
            entity.update({'view_count': 1})
            client.put(entity)
            print(f"Entity '{name}' of kind '{kind}' inserted.")
        else:
            entity['view_count'] = entity.get('view_count', 0) + 1
            client.put(entity)
            print(f"Entity '{name}' of kind '{kind}' already exists and was updated.")

    site_view_count = {"view_count": entity['view_count']}

    return site_view_count
    


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))