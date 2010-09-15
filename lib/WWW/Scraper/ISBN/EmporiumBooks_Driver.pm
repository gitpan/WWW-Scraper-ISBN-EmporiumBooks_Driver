package WWW::Scraper::ISBN::EmporiumBooks_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.02';

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::EmporiumBooks_Driver - Search driver for Emporium Books online book catalog.

=head1 SYNOPSIS

See parent class documentation (L<WWW::Scraper::ISBN::Driver>)

=head1 DESCRIPTION

Searches for book information from Emporium Books online book catalog

=cut

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use WWW::Mechanize;

###########################################################################
# Constants

use constant	SEARCH	=> 'http://www.emporiumbooks.com.au/book-search/search.do?authorName=&title=&isbn=%s&all=%s&keywords=&sort=&txtQuery=%s&searchBy=all';
my ($URL1,$URL2,$URL3) = ('http://www.emporiumbooks.com.au/','<h3 class="bookTitle-browse"><a href="(/book/.*?-','\.do)" title="[^"]+">[^<]+</a></h3>');

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

=head1 METHODS

=over 4

=item C<search()>

Creates a query string, then passes the appropriate form fields to the Word 
Power server.

The returned page should be the correct catalog page for that ISBN. If not the
function returns zero and allows the next driver in the chain to have a go. If
a valid page is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  author
  title
  book_link
  image_link
  description
  pubdate
  publisher
  binding       (if known)
  pages         (if known)
  weight        (if known) (in grammes)
  width         (if known) (in millimetres)
  height        (if known) (in millimetres)

The book_link and image_link refer back to the Emporium Books website.

=back

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

	my $mech = WWW::Mechanize->new();
    $mech->quiet(1);
    $mech->agent_alias( 'Windows IE 6' );
    $mech->add_header('Accept-Encoding' => undef);

    my $url = sprintf SEARCH, $isbn, $isbn, $isbn;
#print STDERR "\n# link0=[$url]\n";

    eval { $mech->get( $url ) };
#print STDERR "\n# error=[$@]\n" if($@);
    return $self->handler("EmporiumBooks website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

    my $pattern = $isbn;
    if(length $isbn == 10) {
        $pattern = '978' . $isbn;
        $pattern =~ s/.$/./;
    }

    my $content = $mech->content;
    my ($link) = $content =~ m!$URL2$pattern$URL3!si;
#print STDERR "\n# link1=[$URL2$pattern$URL3]\n";
#print STDERR "\n# link2=[$URL1$link]\n";
#print STDERR "\n# content1=[\n$content\n]\n";
#print STDERR "\n# is_html=".$mech->is_html().", content type=".$mech->content_type()."\n";
#print STDERR "\n# dump headers=".$mech->dump_headers."\n";

	return $self->handler("Failed to find that book on EmporiumBooks website.")
	    unless($link);

    eval { $mech->get( $URL1 . $link ) };
    return $self->handler("EmporiumBooks website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on EmporiumBooks website. [$isbn]")
		if($html =~ m!Sorry, we couldn't find any matches for!si);
    
#print STDERR "\n# content2=[\n$html\n]\n";

    $html =~ s/&nbsp;/ /g;
    $html =~ s/&#39;/'/g;

    my $data;
    ($data->{isbn13})                   = $html =~ m!<b>ISBN:</b>\s*<h2 id="productDetails-ISBN">([^<]+)</h2><br />!si;
    ($data->{isbn10})                   = $html =~ m!<b>ISBN 10:</b>\s*([^<]+)!si;
    ($data->{publisher})                = $html =~ m!<b>Publisher:</b>\s*([^<]+)<br />!si;
    ($data->{pubdate})                  = $html =~ m!<b>Publication Date:</b>\s*([^<]+)!si;
    ($data->{title})                    = $html =~ m!<h1 class="bookTitle-details">([^<]+)<br/></h1>!si;
    ($data->{binding})                  = $html =~ m!<b>Format:</b>\s*([^<]+)!si;
    ($data->{pages})                    = $html =~ m!<b>Pages:</b>\s*([\d.]+)<br />!si;
    ($data->{width},$data->{height})    = $html =~ m!<b>Dimensions:</b>\s*Width: ([\d.]+)cm\s*,\s*Height: [\d.]+cm\s*,\s*Length: ([\d.]+)cm!si;
    ($data->{weight})                   = $html =~ m!<b>Weight:</b>\s*([\d.]+)kg<br />!si;
    ($data->{author})                   = $html =~ m!<b>Author:</b>\s*<a href="[^"]+" title="[^"]+">([^<]+)</a><br />!si;
    ($data->{image})                    = $html =~ m!"/(images/products/\d+/\d+/\d+/\d+.jpg)"!si;
    ($data->{description})              = $html =~ m!<h3>Overview</h3>\s*<p>([^<]+)!si;

    $data->{width}  = int($data->{width}  * 10)     if($data->{width});
    $data->{height} = int($data->{height} * 10)     if($data->{height});
    $data->{weight} = int($data->{weight} * 1000)   if($data->{weight});

    if($data->{image}) {
        $data->{image} = $URL1 . $data->{image};
        $data->{thumb} = $data->{image};
    }

#use Data::Dumper;
#print STDERR "\n# " . Dumper($data);

	return $self->handler("Could not extract data from EmporiumBooks result page.")
		unless(defined $data);

	# trim top and tail
	foreach (keys %$data) { 
        next unless(defined $data->{$_});
        $data->{$_} =~ s!&nbsp;! !g;
        $data->{$_} =~ s/^\s+//;
        $data->{$_} =~ s/\s+$//;
    }

	my $bk = {
		'ean13'		    => $data->{isbn13},
		'isbn13'		=> $data->{isbn13},
		'isbn10'		=> $data->{isbn10},
		'isbn'			=> $data->{isbn13},
		'author'		=> $data->{author},
		'title'			=> $data->{title},
		'book_link'		=> $mech->uri(),
		'image_link'	=> $data->{image},
		'thumb_link'	=> $data->{thumb},
		'description'	=> $data->{description},
		'pubdate'		=> $data->{pubdate},
		'publisher'		=> $data->{publisher},
		'binding'	    => $data->{binding},
		'pages'		    => $data->{pages},
		'weight'		=> $data->{weight},
		'width'		    => $data->{width},
		'height'		=> $data->{height}
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
}

1;

__END__

=head1 REQUIRES

Requires the following modules be installed:

L<WWW::Scraper::ISBN::Driver>,
L<WWW::Mechanize>

=head1 SEE ALSO

L<WWW::Scraper::ISBN>,
L<WWW::Scraper::ISBN::Record>,
L<WWW::Scraper::ISBN::Driver>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Scraper-ISBN-EmporiumBooks_Driver).
However, it would help greatly if you are able to pinpoint problems or even
supply a patch.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010 Barbie for Miss Barbell Productions

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
