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

  await db.runSql(`CREATE EXTENSION IF NOT EXISTS postgis;`);

  await db.runSql(`
    CREATE TABLE drawings.drawings (
      id SERIAL PRIMARY KEY,
      owner VARCHAR(100) NOT NULL,
      title VARCHAR(255),
      drawing geometry(MultiPolygon, 4326) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);

  await db.runSql(`
    CREATE INDEX idx_drawings_drawing
    ON drawings.drawings
    USING GIST (drawing);
  `);
};

exports.down = async function(db) {
  await db.runSql(`DROP TABLE drawings.drawings;`);
  await db.runSql(`DROP SCHEMA drawings CASCADE;`);
};

exports._meta = {
  "version": 1
};
