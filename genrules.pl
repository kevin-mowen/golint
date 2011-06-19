#!/usr/bin/perl

# Copyright 2011 The Golint Authors. All rights reserved.
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

sub getNameparts {
	$name = shift;
	chomp $name;
	@nameparts = split /:/, $name;
	$category = $nameparts[0];
	$name = $nameparts[1];
	$name2 = $name;
	$name2 =~ s/-/_/g;
	return ($category, $name, $name2)
}

open RULES, ">go/lint/rules.go";

open FIN, "rules/header.go";
while ($line = <FIN>) {
	print RULES $line;
}
close FIN;

print RULES <<END;
/* THIS FILE IS AUTOMATICALLY GENERATED BY genrules.pl */

var LineLinters = []LineLinter{
END

open FIN, "rules/line-raw";
while ($line = <FIN>) {
	chomp $line;
	print RULES "$line,\n" if length($line)>0;
}
close FIN;

open FIN, "rules/line-regex";
while (<FIN>) {
	$name = $_;
	$regex = <FIN> or break;
	chomp $regex;
	$regex =~ s/^\t//;
	$desc = <FIN> or break;
	chomp $desc;
	$desc =~ s/^\t//;
	($category, $name, $name2) = getNameparts $name;
	print RULES <<END;
// $category:$name - $desc ($regex)
RegexLinter{
\tLinterDesc{
\t\t"$category",
\t\t"$name",
\t\t"$desc"},
\t`$regex`},
END
	<FIN>;
}
close FIN;

opendir DIR, "rules/line-simple" or die "Could not read rules/line-simple: $!";
@fnames = ();
while ($fname = readdir(DIR)) {
	push @fnames, $fname;
}
@fnames = sort @fnames;
closedir DIR;

for $fname (@fnames) {
	next if $fname =~ /^\./;
	open FIN, "rules/line-simple/$fname" or die "Could not open $fname: $!";
	$name = <FIN>;
	($category, $name, $name2) = getNameparts $name;
	$desc = <FIN>;
	chomp $desc;
	# read the rest of the file as code
	$code = "";
	while ($line = <FIN>) {
		$code .= $line;
	}
	$code =~ s/\n+$//msg;
	print RULES <<END;
// $category:$name - $desc
SimpleLineLinter{
\tLinterDesc{
\t\t"$category",
\t\t"$name",
\t\t"$desc"},
\t$code},
END
	close FIN;
}

print RULES <<END;
}

var ParsingLinters = [...]ParsingLinter{
END

open FIN, "rules/parsing-raw";
while ($line = <FIN>) {
	chomp $line;
	print RULES "$line,\n" if length($line)>0;
}
close FIN;

open FIN, "rules/deprecation/variables";
while ($line = <FIN>) {
	chomp $line;
	next if length($line) < 2;
	@fields = split /\t+/, $line;
	$name = shift @fields;
	$package = shift @fields;
	$var = shift @fields;
	$desc = shift @fields;
	$rest = join '\t', @fields;
	if ($rest =~ /gofix:([a-zA-Z0-9]+)/) {
		$gofix = $1
	}
	print RULES <<END;
VariableDeprecationLinter{
\t// $line
\tLinterDesc{
\t\t"deprecation",
\t\t"$name",
\t\t"$desc"},
\t"$package",
\t"$var",
\tDeprecationNotes{
\t\t"$gofix"}},
END
}
close FIN;

open FIN, "rules/deprecation/functions";
while ($line = <FIN>) {
	chomp $line;
	next if length($line) < 2;
	@fields = split /\t+/, $line;
	$name = shift @fields;
	$package = shift @fields;
	$func = shift @fields;
	$argString = shift @fields;
	$desc = shift @fields;
	$rest = join '\t', @fields;
	if ($rest =~ /gofix:([a-zA-Z0-9]+)/) {
		$gofix = $1
	}
	@args = split /,/,$argString;
	print RULES <<END;
FunctionDeprecationLinter{
\t// $line
\tLinterDesc{
\t\t"deprecation",
\t\t"$name",
\t\t"$desc"},
\t"$package",
\t"$func",
\t[]string{
END
	for $arg (@args) {
		print RULES "\t\t\"$arg\",\n";
	}
	print RULES <<END;
\t},
\tDeprecationNotes{
\t\t"$gofix"}},
END
}
close FIN;

print RULES <<END;
}
END

close RULES;

