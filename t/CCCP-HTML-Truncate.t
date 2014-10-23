# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl CCCP-HTML-Truncate.t'

use Test::More tests => 4;
BEGIN { 
    use_ok('CCCP::HTML::Truncate');
};

    can_ok('CCCP::HTML::Truncate', 'truncate');
    
    my $html = "<p><b>�����</b> &mdash; ���</p>
    <p><b>�����</b> &mdash; ���</p>\n
    <p><b>�����</b> &mdash; ����� ����!</p>\n";
    
    ok(CCCP::HTML::Truncate->truncate($html,11) eq '<p><b>�����</b> &#x2014; ���</p>&#x2026;','truncate koi8-r character');
    ok(CCCP::HTML::Truncate->truncate($html,11,' &#x262D;') eq '<p><b>�����</b> &#x2014; ���</p> &#x262D;','truncate koi8-r character with elips');