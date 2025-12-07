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
  await db.runSql(`
    CREATE TABLE drawings.likes (
      drawing_id UUID PRIMARY KEY REFERENCES drawings.drawings(drawing_id) ON DELETE CASCADE,
      like_count INTEGER NOT NULL DEFAULT 0
    );
  `);

  await db.runSql(`
    INSERT INTO drawings.likes (drawing_id, like_count)
    SELECT drawing_id, 0 FROM drawings.drawings;
  `);
};

exports.down = async function(db) {
  await db.runSql(`DROP TABLE drawings.likes;`);
};

exports._meta = {
  "version": 1
};

