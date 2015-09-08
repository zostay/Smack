# Smack - Reference implementation of Perl 6 Standard Gateway Interface

This aims to be the reference implementation of the P6SGI standard. The aims of
this project include:

* Providing an example implementation of P6SGI to aid the development of other
  servers.

* Provide a set of tools and utilities to aid in the building of applications
  and middleware.

* Provide a testing ground for future extensions and modifications to P6SGI.

* Provide a testing ground for determining how difficult P6SGI is to implement
  at all layers of development.

## Status

The current status of this code is VERY ALPHA. The P6SGI specification is still
wet on the paper and this implementation is very green. The standalone server
works and is generally compatible with the 0.4.Draft of P6SGI (as of this
writing, I have just started on 0.5.Draft which this server does not yet
support). There is practically no documentation at this point.

At this point, I am in the process of porting the features of Plack to Smack as
a way of testing whether or not the P6SGI specification is feasible. The goal is
to make sure that the easy things are easy and the hard things are possible.
