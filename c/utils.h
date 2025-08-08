#ifndef UTILS_H
#define UTILS_H

/**
 * Prod.mk a b
 */
static inline lean_object * lean_mk_tuple(lean_object * a, lean_object * b) {
  lean_object* tuple = lean_alloc_ctor(0, 2, 0);
  lean_ctor_set(tuple, 0, a);
  lean_ctor_set(tuple, 1, b);
  return tuple;
}

/**
 * Except.ok a
 */
static inline lean_object * lean_mk_except_ok(lean_object * a) {
  lean_object* tuple = lean_alloc_ctor(1, 1, 0);
  lean_ctor_set(tuple, 0, a);
  return tuple;
}


/**
 * Except.err a
 */
static inline lean_object * lean_mk_except_err(lean_object * a) {
  lean_object* tuple = lean_alloc_ctor(0, 1, 0);
  lean_ctor_set(tuple, 0, a);
  return tuple;
}


/**
 * Option.some a
 */
static inline lean_object * lean_mk_option_some(lean_object * a) {
  lean_object* tuple = lean_alloc_ctor(1, 1, 0);
  lean_ctor_set(tuple, 0, a);
  return tuple;
}

/**
 * Option.none.
 * Note that this is the same value for Unit and other constant constructors of inductives.
 */
static inline lean_object * lean_mk_option_none() {
  return lean_box(0);
}

static inline bool lean_option_is_none(lean_object *r) { return lean_ptr_tag(r) == 0; }
static inline bool lean_option_is_some(lean_object *r) { return lean_ptr_tag(r) == 1; }


#endif
