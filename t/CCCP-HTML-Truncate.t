# Before `make install' is performed this script should be runnable with

use Test::More tests => 4;
BEGIN { 
    use_ok('CCCP::HTML::Truncate');
};

    can_ok('CCCP::HTML::Truncate', 'truncate');
    
    my $html = "<p><b>Ленин</b> &mdash; жил</p>
    <p><b>Ленин</b> &mdash; жив</p>\n
    <p><b>Ленин</b> &mdash; будет жить!</p>\n";
    
    ok(CCCP::HTML::Truncate->truncate($html,11) eq '<p><b>Ленин</b> &#x2014; жил</p>&#x2026;','truncate utf-8 character');
    ok(CCCP::HTML::Truncate->truncate($html,11,' &#x262D;') eq '<p><b>Ленин</b> &#x2014; жил</p> &#x262D;','truncate utf-8 character with elips');