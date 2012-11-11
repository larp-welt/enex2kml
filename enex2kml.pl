#!/usr/bin/perl -w
use strict;
use Encode;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;

my $inFile = '';
my $outFile = '';
my $verbose = 0;
my $showSkipped = 0;
my $foldername = 'Evernote';

GetOptions( 'i|input=s' => \$inFile,
			'o|output=s' => \$outFile,
			'v|verbose' => \$verbose,
			's|showSkipped' => \$showSkipped,
			'f|folder=s' => \$foldername);

my $count = 0;
my $exported = 0;

my $parser = XML::LibXML->new();
my $notes = $parser->parse_file($inFile);

my $kml = XML::LibXML::Document->new('1.0', 'utf-8');
my $root = $kml->createElement('kml');
$root->setAttribute('xmlns'=> 'http://www.opengis.net/kml/2.2');
my $document = $kml->createElement('Document');
my $folder = $kml->createElement('Folder');
my $name = $kml->createElement('name');
$name->appendTextNode($foldername);
$root->appendChild($document);
$folder->appendChild($name);
$kml->setDocumentElement($root);

my $style = $kml->createElement('Style');
$style->setAttribute('id' => 'done_style');
my $iconStyle = $kml->createElement('IconStyle');
$style->appendChild($iconStyle);
my $scale = $kml->createElement('scale');
$scale->appendTextNode('1.3');
$iconStyle->appendChild($scale);
my $icon = $kml->createElement('Icon');
$iconStyle->appendChild($icon);
my $href = $kml->createElement('href');
$href->appendTextNode('http://maps.google.com/mapfiles/kml/pushpin/grn-pushpin.png');
$icon->appendChild($href);
my $hotspot = $kml->createElement('hotSpot');
$hotspot->setAttribute('x', '20');
$hotspot->setAttribute('y', '2');
$hotspot->setAttribute('xunits', 'pixels');
$hotspot->setAttribute('yunits', 'pixels');
$icon->appendChild($hotspot);

$document->appendChild($style);
$document->appendChild($folder);

foreach my $note ($notes->findnodes('/en-export/note')) {
	my($title) = $note->findnodes('./title');
	my($lat) = $note->findnodes('./note-attributes/latitude');
	my($long) = $note->findnodes('./note-attributes/longitude');

	my @t = $note->findnodes('./tag');
	my @tags = ();
	my $done = "No";
	foreach my $tag (@t) {
		push(@tags, $tag->to_literal);
		if ($tag->to_literal eq "Done") {$done = "Yes";}
	}

	if ($verbose && $lat && $long) {
		print encode_utf8($title->to_literal), "\n";
		print "\tlatitude:\t", $lat->to_literal, "\n";
		print "\tlongitude:\t", $long->to_literal, "\n";
		print "\ttags:\t".join(', ', @tags)."\n";
		print "\tdone:\t", $done, "\n";
	}

	$count++;

	if ($lat && $long && $lat->to_literal != 0 && $long->to_literal != 0) {
		$exported++;

		my $place = $kml->createElement('Placemark');
		my $name = $kml->createElement('name');
		$name->appendTextNode($title->to_literal);

		my $point = $kml->createElement('Point');
		my $coord = $kml->createElement('coordinates');
		$coord->appendTextNode($long->to_literal.','.$lat->to_literal.',0');
		$point->appendChild($coord);
		my $styleurl = $kml->createElement('styleUrl');
		$styleurl->appendTextNode('#done_style');
		
		$place->appendChild($name);
		if ($done eq 'Yes') { $place->appendChild($styleurl); }
		$place->appendChild($point);
		$folder->appendChild($place);
	} elsif ($showSkipped) {
		print encode_utf8("Skipped: ".$title->to_literal."\n");
	}
}


open KMLOUT, ">", $outFile or die $!;
print KMLOUT $kml->toString(1);
close KMLOUT;

my $skipped = $count-$exported;
print "\ninput:\t$inFile\n";
print "output:\t$outFile\n";
print "Notes read:\t$count\n";
print "Notes exported:\t$exported\n";
print "Notes skipped:\t".$skipped."\n";
