#!/bin/bash
set -e
mongosh --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --eval "db.getSiblingDB('cambodia_shop').createUser({user: '$SHOP_DB_USERNAME', pwd: '$SHOP_DB_PASSWORD', roles: [{role: 'readWrite', db: 'cambodia_shop'}]})"
