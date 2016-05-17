import options, leveldb/raw

proc free(p: pointer) {.importc.}

type
  LevelDb* = ref object
    db: ptr leveldb_t
    syncWriteOptions: ptr leveldb_writeoptions_t
    asyncWriteOptions: ptr leveldb_writeoptions_t
    readOptions: ptr leveldb_readoptions_t

  LevelDbException* = object of Exception

proc checkError(errPtr: cstring) =
  if errPtr != nil:
    defer: free(errPtr)
    raise newException(LevelDbException, $errPtr)

proc close*(self: LevelDb) =
  if self.db == nil:
     return
  leveldb_close(self.db)
  leveldb_writeoptions_destroy(self.syncWriteOptions)
  leveldb_writeoptions_destroy(self.asyncWriteOptions)
  leveldb_readoptions_destroy(self.readOptions)
  self.db = nil

proc open*(path: string): LevelDb =
  new(result, close)

  let options = leveldb_options_create()
  leveldb_options_set_create_if_missing(options, 1.cuchar)
  defer: leveldb_options_destroy(options)

  result.syncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.syncWriteOptions, cuchar(1))
  result.asyncWriteOptions = leveldb_writeoptions_create()
  leveldb_writeoptions_set_sync(result.asyncWriteOptions, cuchar(0))
  result.readOptions = leveldb_readoptions_create()

  var errPtr: cstring = nil
  result.db = leveldb_open(options, path, addr errPtr)
  checkError(errPtr)

proc put*(self: LevelDb, key: string, value: string, sync=true) =
  assert self.db != nil
  var errPtr: cstring = nil
  let writeOptions = if sync: self.syncWriteOptions else: self.asyncWriteOptions
  leveldb_put(self.db, writeOptions,
              key, key.len.csize, value, value.len.csize, addr errPtr)
  checkError(errPtr)

proc get*(self: LevelDb, key: string): Option[string] =
  var size: csize
  var errPtr: cstring = nil
  let s = leveldb_get(self.db, self.readOptions, key, key.len, addr size, addr errPtr)
  checkError(errPtr)

  if s == nil:
    result = none(string)
  else:
    result = some($s)
    free(s)

when isMainModule:
  let db = leveldb.open("test.db")
  db.put("hello", "world")
  echo db.get("one")
  echo db.get("hello")
