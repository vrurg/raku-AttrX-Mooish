use v6;
use lib 'lib';
use Test;
plan 1;

constant AUTHOR = ?%*ENV<AUTHOR_TESTING>; 

if AUTHOR { 
    require Test::META <&meta-ok>;
    meta-ok;
}
else {
     skip-rest "Skipping author test";
}

done-testing;

# vim: ft=perl6
