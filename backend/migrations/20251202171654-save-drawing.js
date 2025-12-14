'use strict';

var dbm;
var type;
var seed;

exports.setup = function(options, seedLink) {
  dbm = options.dbmigrate;
  type = dbm.dataType;
  seed = seedLink;
};

exports.up = async function(db) {
  await db.runSql(`CREATE SCHEMA drawings;`);
  await db.runSql(`CREATE SCHEMA "user";`);

  await db.runSql(`
    CREATE TABLE "user".artist_name (
      user_id VARCHAR(255) PRIMARY KEY,
      artist_name VARCHAR(100) NOT NULL UNIQUE
    );
  `);

  await db.runSql(`
    CREATE TABLE "user".ink (
      user_id VARCHAR(255) PRIMARY KEY,
      ink INTEGER NOT NULL DEFAULT 1000,
      last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await db.runSql(`
    CREATE TABLE drawings.drawings (
      id SERIAL PRIMARY KEY,
      owner_id VARCHAR(255) NOT NULL REFERENCES "user".artist_name(user_id) ON DELETE CASCADE,
      title VARCHAR(255),
      segments JSONB,
      comments_enabled BOOLEAN DEFAULT TRUE,
      is_public BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await db.runSql(`
    CREATE TABLE drawings.likes (
      drawing_id INTEGER REFERENCES drawings.drawings(id) ON DELETE CASCADE,
      user_id VARCHAR(255) NOT NULL,
      PRIMARY KEY (drawing_id, user_id)
    );
  `);

  await db.runSql(`
    CREATE TABLE drawings.comments (
      id SERIAL PRIMARY KEY,
      drawing_id INTEGER REFERENCES drawings.drawings(id) ON DELETE CASCADE,
      artist_name VARCHAR(100) NOT NULL,
      content VARCHAR(1000) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);
};

exports.down = async function(db) {
  await db.runSql(`DROP SCHEMA drawings CASCADE;`);
  await db.runSql(`DROP SCHEMA "user" CASCADE;`);
};

exports._meta = {
  "version": 1
};
