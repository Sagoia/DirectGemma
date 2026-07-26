# Highway source

This directory vendors the `hwy` source tree from Google Highway commit
`2a16a50ff61071bb25ddef0ce35d92b0e2b9c579`.

The native MSVC projects build both `hwy` and `hwy_contrib` directly. Highway
is kept in source form because the required `hwy_contrib` library is not
provided by the vcpkg package used by this project. See `LICENSE` for the
upstream license.
