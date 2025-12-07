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

  await db.runSql(`
    CREATE TABLE drawings.drawings (
      id SERIAL PRIMARY KEY,
      owner VARCHAR(100) NOT NULL,
      title VARCHAR(255),
      segments JSONB,
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
      username VARCHAR(100) NOT NULL,
      content TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);
};

exports.down = async function(db) {
  await db.runSql(`DROP TABLE drawings.comments;`);
  await db.runSql(`DROP TABLE drawings.likes;`);
  await db.runSql(`DROP TABLE drawings.drawings;`);
  await db.runSql(`DROP SCHEMA drawings CASCADE;`);
};

exports._meta = {
  "version": 1
};
