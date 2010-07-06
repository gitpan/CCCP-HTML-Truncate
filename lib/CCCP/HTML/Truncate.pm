package CCCP::HTML::Truncate;

use strict;
use warnings;

our $VERSION = '0.03';

use HTML::TreeBuilder;
use HTML::Entities qw();
use Encode;

# default cyrillic charset
$Patched::HTML::Truncate::enc = 'koi8-r';

my $xml_entities = {
    '&' => '&amp;',
    '"' => '&#x22;',
    "'" => '&#x27;',
    '>' => '&gt;',
    '<' => '&lt;'
};

# we need a few package variable (is't "thread safe" mode)
my $stash = {
    # default elips &#8230; 
    # in numeric mode:
    def_elips => '&#x2026;',
    enc_utf => find_encoding('utf-8'), 
    
    # redefined fields
    # custom elips
    cur_elips => undef,
    # needed length
    max_length => 0,
    # current length
    cur_length => 0,
    # add status elips
    elips_status => 0,
    # utf_flag
    utf => 0,
    # stoped flag
    stop => 0,
    # current default encoding
    enc_cur => undef
};

# clear stash between call methods
sub _clear_stash {
    map {$stash->{$_} = undef} ('cur_elips','enc_cur');
    map {$stash->{$_} = 0} ('max_length','cur_length','elips_status','stop','utf');
}

# truncate html
sub truncate {
    my ($class,$html_str,$length,$elips) = @_;
    
    # clear stash
    $class->_clear_stash();
    my @ret = ();
    
    # check source string on utf
    Encode::_utf8_on($html_str);
    $stash->{utf} = (utf8::valid($html_str) and $html_str =~ /[^\p{InBasic_Latin}|\p{isLatin}]/gm) ? 1 : 0;
    unless ($stash->{utf}) {
        Encode::_utf8_off($html_str);       
    };
    
    # some check
    return unless $html_str;
    
    # save curent elips
    $stash->{cur_elips} = $elips;
    
    # check length
    return '' unless $length;   
    $length ||= 0;
    $length =~ /(\d+)/;
    $length = $1 || 0;
    return '' unless $length;
    
    # return if source string have small length
    if (length $html_str <= $length) {
        # replace entities to numeric if this needed
        if ($html_str =~ /&([a-z]+|#\d+);/i) {
            HTML::Entities::decode($html_str);
            $html_str = $class->_encode_entities($html_str);
        };      
        push @ret,$html_str;
    } else {
        # save length
        $stash->{max_length} = $length;
        $stash->{cur_length} = 0;
        
        # make html tree
        my $root = HTML::TreeBuilder->new_from_content($html_str);
        # iterate html elements
        foreach ($root->disembowel()) {
            next unless $_;
            unless (ref $_) {
                # $_ is a string
                push @ret,__PACKAGE__->_truncated_text($_);
            } elsif (not $stash->{stop}) {
                # $_ is a HTML::Element object
                push @ret,__PACKAGE__->_get_html($_);
            } else {
                $stash->{elips_status} = 2 unless $stash->{elips_status};
                last;
            };
        };
        $root = $root->delete;
    };
    
    push @ret,($stash->{cur_elips} || $stash->{def_elips}) if $stash->{elips_status} == 2;
    my $ret = join('',@ret);
    # after we build html tree, all entities is decoded, and truncated html have utf-8 flag
    if (Encode::is_utf8($ret) and not $stash->{utf} and $Patched::HTML::Truncate::enc !~ /utf/i) {
        Encode::from_to($ret,$Patched::HTML::Truncate::enc,$Patched::HTML::Truncate::enc) 
    } else {
        Encode::_utf8_off($ret);
    };
    
    $ret;
}

# inner method - truncate text
sub _truncated_text {
    my ($class,$str) = @_;
    
    # stoped if we have needed length
    my $need_length =  $stash->{max_length} - $stash->{cur_length};
    unless ($need_length and $need_length > 0) {
        $stash->{stop}++;
        return '';
    };
    
    # HTML::TreeBuilder decode html entities, i.e. string
    # &#8230; &mdash; &#x2605; cccp &#x262D;
    # convert to
    # \x{2026} \x{2014} \x{2605} cccp \x{262D} 
    # and we can used substr 
    my $new_str;
    if ($stash->{utf}) {
        my @new_str = $str =~ /([\p{InBasic_Latin}]|[\p{isLatin}][^\p{isLatin}]|[\P{isLatin}|\p{isLatin}]|[\p{InBasic_Latin}][^\p{InBasic_Latin}]|[\P{InBasic_Latin}|\p{InBasic_Latin}])/gm;
        my $last_char = scalar @new_str > $need_length ? ($need_length-1) : $#new_str; 
        $new_str = join('',@new_str[0..$last_char]); 
        $stash->{cur_length} += $last_char+1;
        # 1-st elips status  - elips contactened in _truncated_text method
        if ($#new_str > $last_char) {
            $stash->{elips_status} = 1;
        };
    } else {
        $new_str = substr($str,0,$need_length);
        $stash->{cur_length} += length $new_str;
        # 1-st elips status  - elips contactened in _truncated_text method
        if (length $new_str < length $str) {
            $stash->{elips_status} = 1;
        }; 
    }; 
    
    # check needed length
    $stash->{stop}++ if $stash->{cur_length} >= $stash->{max_length};
    
    
    # replace decoded entities, and athoter bytes things to numeric html entities
    $new_str = $class->_encode_entities($new_str);
    
    # and add elips if we need do it
    $new_str .= ($stash->{cur_elips} || $stash->{def_elips}) if $stash->{elips_status};
    
    $new_str;   
}

# replace decoded entities, and athoter bytes things to numeric html entities
sub _encode_entities {
    my ($class, $str) = @_;
    return $str unless $str;
    my $exclude = $stash->{utf} ? '' : '|'.join('\|',chr(247),chr(215));    
    if ($stash->{utf}) {
        #$str = $stash->{enc_utf}->encode($str,Encode::FB_XMLCREF);
        $str =~ s/([^\p{Cyrillic}|\p{IsLatin}|\p{InBasic_Latin}${exclude}]|[<|>|'|"|&])/HTML::Entities::encode_entities_numeric($1)/xgem;
    } else {         
        $str =~ s/([^\p{isLatin}|\p{InBasic_Latin}${exclude}]|[<|>|'|"|&])/HTML::Entities::encode_entities_numeric($1)/xgem;
    };  
    $str;
}

# this function make valid html string from HTML::Element tree
sub _get_html {
  my($class,$hent) = @_;
  my @xml = ();
  my $empty_element_map = $hent->_empty_element_map;

  # temp variable
  my($tag, $node, $start);
  my $skiper = {};
  
  # recursion
  $hent->traverse(
    sub {
        ($node, $start) = @_;        
            if(ref $node) {
                # we have tag
                $tag = $node->{'_tag'};
                
                if($start) {                    
                    # add stoped flag if we have needed length
                    $stash->{stop}++ if (not $stash->{stop} and $stash->{cur_length} >= $stash->{max_length});
                    
                    # save in memory open tag (for ignore closed)
                    if ($stash->{stop}) {
                        $skiper->{$tag}++;
                        return 0;
                    };
                    
                    # open tag
                    if($empty_element_map->{$tag} and !@{$node->{'_content'} || []}) {
                        # this is empty tag
                        push(@xml, $node->starttag_XML(undef,1));
                    } else {
                        # this tag may have content
                        push(@xml, $node->starttag_XML(undef));
                    };
                } else {
                    # ignore close tag if open we skip
                    if ($stash->{stop} and exists $skiper->{$tag} and $skiper->{$tag}--) {                      
                        return 0;
                    };
                    
                    # close open tag
                    unless($empty_element_map->{$tag} and !@{$node->{'_content'} || []}) {
                        push(@xml, $node->endtag_XML());
                    };
                };
            } elsif (not $stash->{stop}) {  
              # truncated text
              $node = __PACKAGE__->_truncated_text($node) if $node;
              push @xml,$node;
            } else {
                # in this case we stoped truncate
                # and add elips flag if we heve text over needed length
                $stash->{elips_status} = 2 unless $stash->{elips_status};
            };
        # going on html tree
        1;
      }
  );
  join('',@xml);
}

__END__
=encoding utf-8

=head1 NAME

B<CCCP::HTML::Truncate> - truncate html with html-entities.

I<Version 0.03>

=head1 SYNOPSIS
    
    use CCCP::HTML::Truncate;
    
    my $html = "<p><b>Ленин</b> &mdash; жил</p>
    <p><b>Ленин</b> &mdash; жив</p>\n
    <p><b>Ленин</b> &mdash; будет жить!</p>\n";
    # CASE: Encode::is_utf8($html) eq '0';
    
    print CCCP::HTML::Truncate->truncate($html,11);
    # <p><b>Ленин</b> &#x2014; жил</p>&#x2026;
    
    print CCCP::HTML::Truncate->truncate($html,11,' &#x262D;');
    # <p><b>Ленин</b> &#x2014; жил</p> &#x262D;
    
=head1 DESCRIPTION

Truncate html string. Correct job with html entities.
Validate truncated html.

=head1 METHODS

=head3 truncate($str,$length,$elips)

Class method.
Return truncated html string.

=head1 PACKAGE VARIABLES

=head3 $Patched::HTML::Truncate::enc

If source string in 'utf-8', return truncated 'utf-8', otherwise return truncated string in $Patched::HTML::Truncate::enc.
Default 'koi8-r'

=head1 SEE ALSO

C<HTML::TreeBuilder>, C<Encode>, C<HTML::Entities>, unicode regexp

=head1 AUTHOR

Ivan Sivirinov

=cut
