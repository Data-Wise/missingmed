.onLoad <- function(libname, pkgname) {
  # Register S7 classes/methods for S3/S4 dispatch compatibility.
  S7::methods_register()
}
