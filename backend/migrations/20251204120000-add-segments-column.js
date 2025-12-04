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
    ALTER TABLE drawings.drawings
    ADD COLUMN segments JSONB;
  `);
};

exports.down = async function(db) {
  await db.runSql(`
    ALTER TABLE drawings.drawings
    DROP COLUMN segments;
  `);
};

exports._meta = {
  "version": 1
};



