#!/usr/bin/perl -w

package ScrambleSolver;

use Tree;
use Graph;

sub stringHasPath {
	my $dictionaryTree = shift;
	my $stringToCheck = shift;
	
	my $currentNode = $dictionaryTree;
	
	my @characters = split(//, $stringToCheck);
	for (my $i = 0; $i < scalar(@characters); $i++) {
		my $hasChild = 0;
		for my $child ($currentNode->children()) {
			if ($child->value() eq $characters[$i]) {
				$currentNode = $child;
				$hasChild = 1;
				last;
			}
		}
		
		if ($hasChild != 1) {
			return 0;
		}
	}
	
	# Check if the final node has a '0' character - means the string is completed
	for my $child ($currentNode->children()) {
		if ($child->value() eq "0") {
			return 2;
		}
	}
	
	# If we didn't return from seeing '0', the string was not complete, but there was a valid path
	return 1;
}

sub depthFirstSearch {
	my $boardGraph = shift;
	my $dictionaryTree = shift;
	my $vertex = shift;
	my $string = shift;
	my $path = shift;
		
	my $letter = substr($vertex, 0, 1);
	my $position = substr($vertex, 1, length($vertex));
	
	$string = $string . $letter;
	push(@{$path}, $position);
		
	my $result = stringHasPath($dictionaryTree, $string);
	
	if ($result == 0) {
		return;
	} elsif ($result == 2) {
		$words{$string} = $path;
	}
	
	$boardGraph->set_vertex_attribute($vertex, "visited", 1);
	foreach my $neighbor ($boardGraph->neighbors($vertex)) {
		if (!$boardGraph->has_vertex_attribute($neighbor, "visited")) {
			my @pathCopy = @{$path};
			depthFirstSearch($boardGraph->deep_copy(), $dictionaryTree, $neighbor, $string, \@pathCopy);
		}
	}
}

our %words = ();

my $dictionaryFilesPath = "EOWL-v1.1.1/LF Delimited Format/";
my $dictionaryFilenameEnding = " Words.txt";

# Validate command line arguments
if (scalar(@ARGV) != 1) { die "Usage: scrambleSolver.pl <scramble board>"; }
my $scrambleBoardFilePath = $ARGV[0];

# Read contents of board file
open SCRAMBLEBOARDFILE, $scrambleBoardFilePath or die("Could not specified scramble board file: \"$scrambleBoardFilePath\"");
my @lines = <SCRAMBLEBOARDFILE>;
close SCRAMBLEBOARDFILE;

# Validate scramble board file and create scramble board 2D array
my $scrambleBoard = ();

if (scalar(@lines) != 4) { die "Invalid board file: invalid number of lines"; }
for my $line (@lines) {
	chomp($line);
	if (length($line) != 4) { die "Invalid board file: invalid number of characters on line \"$line\""; }
	if ($line =~ m/[^a-zA-Z]/) { die "Invalid board file: invalid character on line \"$line\""; }
	
	$line = lc($line);
	my @row = split(//, $line);
	push (@scrambleBoard, \@row);
}

# Generate scramble board graph
# Note: Each vertex is the letter followed by the position on the board; this prevents the reuse
# of a vertex for a given letter that appears multiple times on the board
print "Generating scramble board graph...\n";

my $boardGraph = Graph::Undirected->new();

for (my $i = 0; $i < scalar(@scrambleBoard); $i++) {
	for (my $j = 0; $j < scalar(@{$scrambleBoard[$i]}); $j++) {	
		# North
		if ($i > 0) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i - 1]}[$j] . ((($i - 1) * 4) + $j));
		}
		
		# Northeast
		if ($i > 0 && $j < 3) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i - 1]}[$j + 1] . ((($i - 1) * 4) + $j + 1));
		}
		
		# East
		if ($j < 3) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i]}[$j + 1] . (($i * 4) + $j + 1));
		}
		
		# Southeast
		if ($i < 3 && $j < 3) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i + 1]}[$j + 1] . ((($i + 1) * 4) + $j + 1));
		}
		
		# South
		if ($i < 3) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i + 1]}[$j] . ((($i + 1) * 4) + $j));
		}
		
		# Southwest
		if ($i < 3 && $j > 0) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i + 1]}[$j - 1] . ((($i + 1) * 4) + $j - 1));
		}
		
		# West
		if ($j > 0) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i]}[$j - 1] . (($i * 4) + $j - 1));
		}
		
		# Northwest
		if ($i > 0 && $j > 0) {
			$boardGraph->add_edge(@{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), @{$scrambleBoard[$i - 1]}[$j - 1] . ((($i - 1) * 4) + $j - 1));
		}
	}
}

# Ensure dictionary directory exists
opendir DICTIONARYDIR, $dictionaryFilesPath or die("Could not find dictionary files path: \"$dictionaryFilesPath\"");
closedir DICTIONARYDIR;

# Generate dictionary tree
print "Generating dictionary tree...\n";

my $dictionaryTree = Tree->new('root');

for my $letter (A..Z) {
	open DICTIONARYFILE, $dictionaryFilesPath . $letter . $dictionaryFilenameEnding or die("Could not find dictionary file for letter $letter: \"$dictionaryFilesPath$letter$dictionaryFilenameEnding\"");
	while (<DICTIONARYFILE>) {
		chomp;
		$_ = lc;
		
		my @characters = split(//);
		my $currentNode = $dictionaryTree;
		for (my $i = 0; $i < scalar(@characters); $i++) {
			my $childExists = 0;
			
			# If the child exists, set the current node to it
			for my $child ($currentNode->children()) {
				if ($child->value() eq $characters[$i]) {
					$currentNode = $child;				
					$childExists = 1;
					last;
				}
			}
			
			# If the child doesn't already exist, create it, add it to the current node,
			# and set the current node to the newly created node
			if ($childExists == 0) {
				my $newNode = Tree->new($characters[$i]);
				$currentNode->add_child($newNode);
				$currentNode = $newNode;
			}
			
			# If this is the last character, add a '0' child to indicate this completes the word
			if ($i + 1 == scalar(@characters)) {
				my $newNode = Tree->new("0");
				$currentNode->add_child($newNode);
			}
		}
	}
	close DICTIONARYFILE;
}

# Generate all possible words
print "Generating possible words...\n";

# Perform depth first search on each position on graph, checking to see if
# it exists in the dictionary tree
for ($i = 0; $i < scalar(@scrambleBoard); $i++) {
	for ($j = 0; $j < scalar(@{$scrambleBoard[$i]}); $j++) {
		depthFirstSearch($boardGraph->copy_graph(), $dictionaryTree, @{$scrambleBoard[$i]}[$j] . (($i * 4) + $j), "", ());
	}
}

print "Found " . scalar(keys %words) . " words:\n";

foreach my $key (sort(keys %words)) {
	print $key . " | ";
	for (my $i = 0; $i < scalar(@{$words{$key}}); $i++) {
		print @{$words{$key}}[$i];
		if ($i != scalar(@{$words{$key}}) - 1) {
			print " -> ";
		}
	}
	print "\n";
}