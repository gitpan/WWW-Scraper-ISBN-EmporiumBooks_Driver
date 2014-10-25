#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 40;
use WWW::Scraper::ISBN;

###########################################################

my $CHECK_DOMAIN = 'www.google.com';

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", 39   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers("EmporiumBooks");

    # this ISBN doesn't exist
	my $isbn = "1234567890";
    my $record;
    eval { $record = $scraper->search($isbn); };
    if($@) {
        like($@,qr/Invalid ISBN specified/);
    }
    elsif($record->found) {
        ok(0,'Unexpectedly found a non-existent book');
    } else {
		like($record->error,qr/Failed to find that book on EmporiumBooks website|website appears to be unavailable/);
    }

	$isbn = "0552557803";
	$record = $scraper->search($isbn);
    my $error  = $record->error || '';

    SKIP: {
        skip "Website unavailable", 19   if($error =~ /website appears to be unavailable/);

        unless($record->found) {
            diag("ERROR: [$isbn] ".$record->error);
        }
        
        {
            is($record->found,1);
            is($record->found_in,'EmporiumBooks');

            my $book = $record->book;
            is($book->{'isbn'},         '9780552557801'         ,'.. isbn found');
            is($book->{'isbn10'},       '0552557803'            ,'.. isbn10 found');
            is($book->{'isbn13'},       '9780552557801'         ,'.. isbn13 found');
            is($book->{'ean13'},        '9780552557801'         ,'.. ean13 found');
            like($book->{'author'},     qr/Terry Pratchett/     ,'.. author found');
            is($book->{'title'},        q|Nation|               ,'.. title found');
            like($book->{'book_link'},  qr|http://www.emporiumbooks.com.au//book/nation-9780552557801.do|);
            is($book->{'image_link'},   'http://www.emporiumbooks.com.au/images/products/978/174/166/9781741668957.jpg');
            is($book->{'thumb_link'},   'http://www.emporiumbooks.com.au/images/products/978/174/166/9781741668957.jpg');
            like($book->{'description'},qr/When a giant wave destroys his entire Nation/    ,'.. description found');
            is($book->{'publisher'},    'Random House Children\'s Books'                     ,'.. publisher found');
            is($book->{'pubdate'},      '24 September 2009'     ,'.. pubdate found');
            is($book->{'binding'},      'Paperback'             ,'.. binding found');
            is($book->{'pages'},        432                     ,'.. pages found');
            is($book->{'width'},        undef                   ,'.. width found');
            is($book->{'height'},       undef                   ,'.. height found');
            is($book->{'weight'},       undef                   ,'.. weight found');
        }
    }

	$isbn   = "9780571239566";
	$record = $scraper->search($isbn);
    $error  = $record->error || '';

    SKIP: {
        skip "Website unavailable", 19   if($error =~ /website appears to be unavailable/);

        unless($record->found) {
            diag("ERROR: [$isbn] ".$record->error);
        }
        
        {
            is($record->found,1);
            is($record->found_in,'EmporiumBooks');

            my $book = $record->book;
            is($book->{'isbn'},         '9780571239566'         ,'.. isbn found');
            is($book->{'isbn10'},       '0571239560'            ,'.. isbn10 found');
            is($book->{'isbn13'},       '9780571239566'         ,'.. isbn13 found');
            is($book->{'ean13'},        '9780571239566'         ,'.. ean13 found');
            is($book->{'author'},       q|Deborah Curtis|       ,'.. author found');
            is($book->{'title'},        q|Touching from a Distance| ,'.. title found');
            like($book->{'book_link'},  qr|http://www.emporiumbooks.com.au//book/touching-from-a-distance-9780571239566.do|);
            is($book->{'image_link'},   'http://www.emporiumbooks.com.au/images/products/978/174/166/9781741668957.jpg');
            is($book->{'thumb_link'},   'http://www.emporiumbooks.com.au/images/products/978/174/166/9781741668957.jpg');
            like($book->{'description'},qr|Ian Curtis left behind a legacy rich in artistic genius|);
            is($book->{'publisher'},    'Faber and Faber'       ,'.. publisher found');
            is($book->{'pubdate'},      '11 October 2007'       ,'.. pubdate found');
            is($book->{'binding'},      'Paperback'             ,'.. binding found');
            is($book->{'pages'},        240                     ,'.. pages found');
            is($book->{'width'},        129                     ,'.. width found');
            is($book->{'height'},       198                     ,'.. height found');
            is($book->{'weight'},       200                     ,'.. weight found');

            #use Data::Dumper;
            #diag("book=[".Dumper($book)."]");
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    system("ping -q -c 1 $domain >/dev/null 2>&1");
    my $retcode = $? >> 8;
    # ping returns 1 if unable to connect
    return $retcode;
}
