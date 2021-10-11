#!/usr/bin/perl
#
# degruyter.pl
#
# Original: 10/17/2019; redone: 10/08/2021
#
# Process MARC records from DeGruyter, via You Lee, to remove various fields and then edit/add related fields pertaining to our catalog
#
use strict;
use warnings;
# add module for MARC coding
use MARC::Batch;

# Can be executed via command line with appropriate file name,
# or be prompted for file name if executed by double-click

my $mrcFile = $ARGV[0];
unless (exists ($ARGV[0])) {
	# prompts user for file name if executed by double-click
	print "\nPlease enter appropriate .mrc file: \n";
	$mrcFile = <STDIN>;
	chomp $mrcFile;
}
## Create new instance of MARC::Batch for newly input .mrc file
my $batch = MARC::Batch->new('USMARC', $mrcFile);
$mrcFile =~ s/(.+)\.mrc/$1_processed\.mrc/;
open (OUT, ">utf8", $mrcFile) or die $1;

my $count = 1;
## read through each record, delete/add fields where necessary
while (my $record = $batch->next()) {
	
	my @field035 = $record->field('035');
	$record->delete_fields(@field035);
	my @field072 = $record->field('072');
	$record->delete_fields(@field072);
	my @field505 = $record->field('505');
	$record->delete_fields(@field505);
	my @field650 = $record->field('650');
	## delete all 650 field that have a '7' in indicator 2 
	foreach my $field650 (@field650) {
		if ($field650->indicator(2) == 7) {
			$record->delete_field($field650);
		}
	}
	my @field773 = $record->field('773');
	$record->delete_fields(@field773);
	my @field776 = $record->field('776');
	$record->delete_fields(@field776);
	my @field912 = $record->field('912');
	$record->delete_fields(@field912);
	
	## get leader to edit position 17
	my $leader = $record->leader();	 
	## replace position 17 with '7'
	substr($leader,17,1) = '7';	 
	## update the leader
 	$record->leader($leader);
	
	## obtain 001 field
	my $field001 = $record->field('001');
	$field001 = $field001->as_string();
	## add $dNIC
	my $field040 = $record->field('040');
	$field040->add_subfields('d' => 'NIC');
	
	## Cornell proxy
	my $proxy = "http://proxy.library.cornell.edu/login?url=";
	
	## Acquire correct DeGruyter URL before deleting current 856 fields
	my $dgURL = "https://www.degruyter.com/isbn/";
	
	## Now delete all old 856 fields.
	my @old856 = $record->field('856');
	$record->delete_fields(@old856);
	
	## Create new 856 field with appropriate url, dbcode and providercode
	my $add856 = MARC::Field->new('856', '4', '1', 3=> 'Available from DeGruyter.', i=> 'dbcode=AAZEP; providercode=PRVAZK', u=> $proxy . $dgURL . $field001, z=> 'Connect to full text. Access limited to authorized subscribers.');
	$record->insert_fields_ordered($add856);
	## Now add corresponding 899's
	my $add899 = MARC::Field->new('899', '', '', a=> 'degruyterebksmu');
	$record->insert_fields_ordered($add899);
	my $add899b = MARC::Field->new('899', '2', '', a=> 'PRVAZK_AAZEP');
	$record->insert_fields_ordered($add899b);
	## add approriate 906 field
	my $add906 = MARC::Field->new('906', '', '', a=> 'gs');
	$record->insert_fields_ordered($add906);
	
	## Now add all standrad 948's
	my $theDate;
	$record->insert_fields_ordered(MARC::Field->new('948','0','',a=>getdate($theDate),b=>'i',d=>'batch',e=>'lts'));
	$record->insert_fields_ordered(MARC::Field->new('948','1','',a=>getdate($theDate),b=>'s',d=>'batch',e=>'lts',f=>'ebk'));
	$record->insert_fields_ordered(MARC::Field->new('948','3','',a=>getdate($theDate),h=>'PRVAZK_AAZEP',i=>$mrcFile));

	print OUT $record->as_usmarc();
	$count++;
	
} ## end of main block of code

close (OUT);

## Informs user process has been completed ... prompts user to press enter key to close program
print "\n\n**DeGruyter file process complete! \n";
print "There were a total of ", $count, " records processed.\n\n";
print "**Press ENTER key to quit.\n";
<STDIN>;
print "\n";
	
## Subroutine that calculates the date and is called in the main code to have the date inserted
sub getdate{
## setup date for 948 subfields
	my ($dayOfMonth, $month, $yearOffset) = (localtime)[3,4,5];
	my $year = 1900 + $yearOffset;
	my $theMonth = sprintf("%02d", $month + 1);
	my $theday = sprintf("%02d", $dayOfMonth);
	my $theDate = "$year$theMonth$theday";
} ## end of sub getdate