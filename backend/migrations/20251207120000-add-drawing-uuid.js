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
  await db.runSql(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`);

  await db.runSql(`
    ALTER TABLE drawings.drawings
    ADD COLUMN drawing_id UUID;
  `);

  await db.runSql(`
    UPDATE drawings.drawings
    SET drawing_id = uuid_generate_v4()
    WHERE drawing_id IS NULL;
  `);

  await db.runSql(`
    ALTER TABLE drawings.drawings
    ALTER COLUMN drawing_id SET NOT NULL,
    ALTER COLUMN drawing_id SET DEFAULT uuid_generate_v4();
  `);

  await db.runSql(`
    CREATE UNIQUE INDEX idx_drawings_drawing_id ON drawings.drawings(drawing_id);
  `);
};

exports.down = async function(db) {
  await db.runSql(`DROP INDEX IF EXISTS drawings.idx_drawings_drawing_id;`);
  await db.runSql(`ALTER TABLE drawings.drawings DROP COLUMN drawing_id;`);
};

exports._meta = {
  "version": 1
};

