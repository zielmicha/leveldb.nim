## # Copyright (c) 2011 The LevelDB Authors. All rights reserved.
## #  Use of this source code is governed by a BSD-style license that can be
## #  found in the LICENSE file. See the AUTHORS file for names of contributors.
## #
## #  C bindings for leveldb.  May be useful as a stable ABI that can be
## #  used by programs that keep leveldb in a shared library, or for
## #  a JNI api.
## #
## #  Does not support:
## #  . getters for the option types
## #  . custom comparators that implement key shortening
## #  . custom iter, db, env, cache implementations using just the C bindings
## #
## #  Some conventions:
## #
## #  (1) We expose just opaque struct pointers and functions to clients.
## #  This allows us to change internal representations without having to
## #  recompile clients.
## #
## #  (2) For simplicity, there is no equivalent to the Slice type.  Instead,
## #  the caller has to pass the pointer and length as separate
## #  arguments.
## #
## #  (3) Errors are represented by a null-terminated c string.  NULL
## #  means no error.  All operations that can raise an error are passed
## #  a "char** errptr" as the last argument.  One of the following must
## #  be true on entry:
## #     errptr == NULL
## #     errptr points to a malloc()ed null-terminated error message
## #       (On Windows, *errptr must have been malloc()-ed by this library.)
## #  On success, a leveldb routine leaves *errptr unchanged.
## #  On failure, leveldb frees the old value of *errptr and
## #  set *errptr to a malloc()ed error message.
## #
## #  (4) Bools have the type unsigned char (0 == false; rest == true)
## #
## #  (5) All of the pointer arguments must be non-NULL.
## #

{.passl: "-lleveldb".}

## # Exported types 

type
  leveldb_options_t* = object
  leveldb_writeoptions_t* = object
  leveldb_readoptions_t* = object
  leveldb_writebatch_t* = object
  leveldb_iterator_t* = object
  leveldb_snapshot_t* = object
  leveldb_comparator_t* = object
  leveldb_filterpolicy_t* = object
  leveldb_env_t* = object
  leveldb_logger_t* = object
  leveldb_cache_t* = object
  leveldb_t* = object

## # DB operations 

proc leveldb_open*(options: ptr leveldb_options_t; name: cstring; errptr: ptr cstring): ptr leveldb_t {.importc.}
proc leveldb_close*(db: ptr leveldb_t) {.importc.}
proc leveldb_put*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t; key: cstring;
                 keylen: csize; val: cstring; vallen: csize; errptr: ptr cstring) {.importc.}
proc leveldb_delete*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t;
                    key: cstring; keylen: csize; errptr: ptr cstring) {.importc.}
proc leveldb_write*(db: ptr leveldb_t; options: ptr leveldb_writeoptions_t;
                   batch: ptr leveldb_writebatch_t; errptr: ptr cstring) {.importc.}
## # Returns NULL if not found.  A malloc()ed array otherwise.
## #   Stores the length of the array in *vallen. 

proc leveldb_get*(db: ptr leveldb_t; options: ptr leveldb_readoptions_t; key: cstring;
                 keylen: csize; vallen: ptr csize; errptr: ptr cstring): cstring {.importc.}
proc leveldb_create_iterator*(db: ptr leveldb_t; options: ptr leveldb_readoptions_t): ptr leveldb_iterator_t {.importc.}
proc leveldb_create_snapshot*(db: ptr leveldb_t): ptr leveldb_snapshot_t {.importc.}
proc leveldb_release_snapshot*(db: ptr leveldb_t; snapshot: ptr leveldb_snapshot_t) {.importc.}
## # Returns NULL if property name is unknown.
## #   Else returns a pointer to a malloc()-ed null-terminated value. 

proc leveldb_property_value*(db: ptr leveldb_t; propname: cstring): cstring {.importc.}
proc leveldb_approximate_sizes*(db: ptr leveldb_t; num_ranges: cint;
                               range_start_key: ptr cstring;
                               range_start_key_len: ptr csize;
                               range_limit_key: ptr cstring;
                               range_limit_key_len: ptr csize; sizes: ptr uint64) {.importc.}
proc leveldb_compact_range*(db: ptr leveldb_t; start_key: cstring;
                           start_key_len: csize; limit_key: cstring;
                           limit_key_len: csize) {.importc.}
## # Management operations 

proc leveldb_destroy_db*(options: ptr leveldb_options_t; name: cstring;
                        errptr: ptr cstring) {.importc.}
proc leveldb_repair_db*(options: ptr leveldb_options_t; name: cstring;
                       errptr: ptr cstring) {.importc.}
## # Iterator 

proc leveldb_iter_destroy*(a2: ptr leveldb_iterator_t) {.importc.}
proc leveldb_iter_valid*(a2: ptr leveldb_iterator_t): cuchar {.importc.}
proc leveldb_iter_seek_to_first*(a2: ptr leveldb_iterator_t) {.importc.}
proc leveldb_iter_seek_to_last*(a2: ptr leveldb_iterator_t) {.importc.}
proc leveldb_iter_seek*(a2: ptr leveldb_iterator_t; k: cstring; klen: csize) {.importc.}
proc leveldb_iter_next*(a2: ptr leveldb_iterator_t) {.importc.}
proc leveldb_iter_prev*(a2: ptr leveldb_iterator_t) {.importc.}
proc leveldb_iter_key*(a2: ptr leveldb_iterator_t; klen: ptr csize): cstring {.importc.}
proc leveldb_iter_value*(a2: ptr leveldb_iterator_t; vlen: ptr csize): cstring {.importc.}
proc leveldb_iter_get_error*(a2: ptr leveldb_iterator_t; errptr: ptr cstring) {.importc.}
## # Write batch 

proc leveldb_writebatch_create*(): ptr leveldb_writebatch_t {.importc.}
proc leveldb_writebatch_destroy*(a2: ptr leveldb_writebatch_t) {.importc.}
proc leveldb_writebatch_clear*(a2: ptr leveldb_writebatch_t) {.importc.}
proc leveldb_writebatch_put*(a2: ptr leveldb_writebatch_t; key: cstring; klen: csize;
                            val: cstring; vlen: csize) {.importc.}
proc leveldb_writebatch_delete*(a2: ptr leveldb_writebatch_t; key: cstring;
                               klen: csize) {.importc.}
## # Options 

proc leveldb_options_create*(): ptr leveldb_options_t {.importc.}
proc leveldb_options_destroy*(a2: ptr leveldb_options_t) {.importc.}
proc leveldb_options_set_comparator*(a2: ptr leveldb_options_t;
                                    a3: ptr leveldb_comparator_t) {.importc.}
proc leveldb_options_set_filter_policy*(a2: ptr leveldb_options_t;
                                       a3: ptr leveldb_filterpolicy_t) {.importc.}
proc leveldb_options_set_create_if_missing*(a2: ptr leveldb_options_t; a3: cuchar) {.importc.}
proc leveldb_options_set_error_if_exists*(a2: ptr leveldb_options_t; a3: cuchar) {.importc.}
proc leveldb_options_set_paranoid_checks*(a2: ptr leveldb_options_t; a3: cuchar) {.importc.}
proc leveldb_options_set_env*(a2: ptr leveldb_options_t; a3: ptr leveldb_env_t) {.importc.}
proc leveldb_options_set_info_log*(a2: ptr leveldb_options_t;
                                  a3: ptr leveldb_logger_t) {.importc.}
proc leveldb_options_set_write_buffer_size*(a2: ptr leveldb_options_t; a3: csize) {.importc.}
proc leveldb_options_set_max_open_files*(a2: ptr leveldb_options_t; a3: cint) {.importc.}
proc leveldb_options_set_cache*(a2: ptr leveldb_options_t; a3: ptr leveldb_cache_t) {.importc.}
proc leveldb_options_set_block_size*(a2: ptr leveldb_options_t; a3: csize) {.importc.}
proc leveldb_options_set_block_restart_interval*(a2: ptr leveldb_options_t; a3: cint) {.importc.}
const
  leveldb_no_compression* = 0
  leveldb_snappy_compression* = 1

proc leveldb_options_set_compression*(a2: ptr leveldb_options_t; a3: cint) {.importc.}
## # Comparator 
proc leveldb_comparator_destroy*(a2: ptr leveldb_comparator_t) {.importc.}
## # Filter policy 

proc leveldb_filterpolicy_destroy*(a2: ptr leveldb_filterpolicy_t) {.importc.}
proc leveldb_filterpolicy_create_bloom*(bits_per_key: cint): ptr leveldb_filterpolicy_t {.importc.}
## # Read options 

proc leveldb_readoptions_create*(): ptr leveldb_readoptions_t {.importc.}
proc leveldb_readoptions_destroy*(a2: ptr leveldb_readoptions_t) {.importc.}
proc leveldb_readoptions_set_verify_checksums*(a2: ptr leveldb_readoptions_t;
    a3: cuchar) {.importc.}
proc leveldb_readoptions_set_fill_cache*(a2: ptr leveldb_readoptions_t; a3: cuchar) {.importc.}
proc leveldb_readoptions_set_snapshot*(a2: ptr leveldb_readoptions_t;
                                      a3: ptr leveldb_snapshot_t) {.importc.}
## # Write options 

proc leveldb_writeoptions_create*(): ptr leveldb_writeoptions_t {.importc.}
proc leveldb_writeoptions_destroy*(a2: ptr leveldb_writeoptions_t) {.importc.}
proc leveldb_writeoptions_set_sync*(a2: ptr leveldb_writeoptions_t; a3: cuchar) {.importc.}
## # Cache 

proc leveldb_cache_create_lru*(capacity: csize): ptr leveldb_cache_t {.importc.}
proc leveldb_cache_destroy*(cache: ptr leveldb_cache_t) {.importc.}
## # Env 

proc leveldb_create_default_env*(): ptr leveldb_env_t {.importc.}
proc leveldb_env_destroy*(a2: ptr leveldb_env_t) {.importc.}
## # Utility 
## # Calls free(ptr).
## #   REQUIRES: ptr was malloc()-ed and returned by one of the routines
## #   in this file.  Note that in certain cases (typically on Windows), you
## #   may need to call this routine instead of free(ptr) to dispose of
## #   malloc()-ed memory returned by this library. 

proc leveldb_free*(`ptr`: pointer) {.importc.}
## # Return the major version number for this release. 

proc leveldb_major_version*(): cint {.importc.}
## # Return the minor version number for this release. 

proc leveldb_minor_version*(): cint {.importc.}
