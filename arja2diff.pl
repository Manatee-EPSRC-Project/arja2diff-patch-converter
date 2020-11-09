#!/usr/bin/perl


our $prefix="";
my $sourceDir = shift;
my $project=shift;

my $dir=shift;

opendir(DIR, $dir) 
  or die "Cannot open dir $dir";

while(my $file = readdir(DIR)) {
  next unless(-d "$dir/$file");


  $re = qr/$project/;

  next unless ($file =~ /${re}([0-9]+)/);

  my $bug=$1;
  convertPatchesFromDir($dir,$file,$project,$bug);  
  
}

closedir(DIR);
exit 0;


sub convertPatchesFromDir() {
 my $dirOuter = shift;
 my $dirInner = shift;
 my $project = shift;
 my $bug = shift;

	opendir(DIRINNER, $dirOuter . "/" . $dirInner) 
	  or die "Cannot open dir $dirInner";

	while(my $fileInner = readdir(DIRINNER)) {


	  next unless ($fileInner =~ /Patch_([0-9]+)\.txt/);

	my $patchNo=$1;
	print("patch name: $fileInner");
	  convertPatch($dirOuter,$dirInner,$fileInner,$project,$bug,$patchNo);  

	}

closedir(DIRINNER);
}


sub convertPatch() {
	my $dirOuter=shift;
	my $dirInner=shift;
	my $fileName=shift;
	my $project=shift;
	my $bug=shift;
	my $patchNo=shift;


 	  my $fileName=$dirOuter . "/" . $dirInner . "/" . $fileName;
	  open (FILE,"<$fileName")
	    or die "Can't open $fileName";







	  my $operator="";
	  my $originalPath="";
	  my $lineNr=0;

	  my $inStart=1;
	  my $inFaulty=0;
	  my $inSeed=0;
	  my @faulty=();
	  my @seed=();

	  @lines = <FILE>;
	  close FILE;

	  foreach $line (@lines) {
	    if ($inStart==1 && $line =~ m/[0-9]+ (Replace|Delete|InsertBefore) ([\S]+) ([0-9]+)/) {
	      $operator=$1;
	      $originalPath=$2;
	      $patchLineNo=$3;


	      
	      print("$operator $originalPath $patchLineNo\n");
	     }
	    elsif($inStart==1 && $line =~ m/Faulty:/) {
	      $inStart=0;
	      $inFaulty=1;
	    }    
	    elsif($inFaulty==1 && $line =~ m/Seed:/) {
	      $inFaulty=0;
	      $inSeed=1;
	    }    
	    elsif($inSeed==1 && $line =~ m/^(\*)+$/) {
	      $inSeed=0;
	      last;
	    }    
	    elsif($inFaulty==1) {
	      push(@faulty,$line);

	    }    
	    elsif($inSeed==1) { 
	      push(@seed,$line);
	    }    
	    else {
	     print (".");
	   }	

	}

	     print("Faulty:\n");
	     print("@faulty","\n");
	 

	     print("Seed:\n");
	     print("@seed","\n");

	      my $pathSuffixBeg=index($originalPath,"/bugs/");
	      $modifiedPath=$sourceDir . substr($originalPath,$pathSuffixBeg,length($originalPath)-$pathSuffixBeg); 

	      print ("$modifiedPath\n");
	      open (SOURCE,"<$modifiedPath")
	    or die "Can't open $modifiedPath";


	  my @source = <SOURCE>;
	  close SOURCE;

	  open(DEST, ">Patch.txt")
	    or die "Can't create file path.txt";


	  my $lineNo=1;
	  my $omitLines=0;
	my $realLinesToRemove=0;  
#	foreach $line (@source) {
	for (my $index=0; $index<=$#source; $index++ ) {
	  $line=$source[$index];
	  if($lineNo++ !=$patchLineNo) {
	    if($omitLines>0) {
	      $omitLines--;
	    }
	    else {
	      print DEST "$line";
	   }
	  }
	  else {
	    if($operator eq "InsertBefore") {
#	      $omitLines=@faulty-1;
		$main::prefix="";	
            $realLinesToRemove=computeRealLinesToRemove(\@source,\@faulty,$patchLineNo);
		print("\nPREFIX:\n $main::prefix \nPREFIXEND\n");

		if($main::prefix!~ /^[ \t]+$/) {

			print "PREFIX=$main::prefix\n";
			print DEST "$main::prefix";	
		}
		$main::prefix="";

		$omitLines=0; #$realLinesToRemove-1;
	      print("OmitLines=$omitLines\n");
	      foreach $seedLine (@seed) {
		print DEST "$seedLine";
	      }
	      print DEST "$line";
	    }
	    elsif($operator eq "Replace") {
#	      $omitLines=@faulty-1;
		$main::prefix="";	
            $realLinesToRemove=computeRealLinesToRemove(\@source,\@faulty,$patchLineNo);
		print("\nPREFIX:\n $main::prefix \nPREFIXEND\n");

		if($main::prefix!~ /^[ \t]+$/) {

			print "PREFIX=$main::prefix\n";
			print DEST "$main::prefix";	
		}
		$main::prefix="";

		$omitLines=$realLinesToRemove-1;
	      print("OmitLines=$omitLines\n");
	      foreach $seedLine (@seed) {
		print DEST "$seedLine";
	      }
	    }
	    elsif($operator eq "Delete") {
#	      $omitLines=@faulty-1;
		$main::prefix="";	
            $realLinesToRemove=computeRealLinesToRemove(\@source,\@faulty,$patchLineNo);
		print("\nPREFIX:\n $main::prefix \nPREFIXEND\n");

		if($main::prefix!~ /^[ \t]+$/) {

			print "PREFIX=$main::prefix\n";
			print DEST "$main::prefix";	
		}
		$main::prefix="";

		$omitLines=$realLinesToRemove-1;
	      print("OmitLines=$omitLines\n");
	    }
	   
	  }

	}

	  close (DEST);

	$ucProject=ucfirst($project);
  my $patchName="patch${patchNo}-$ucProject-$bug-OneEdit.patch";
  system("diff -u $modifiedPath Patch.txt >$patchName");  
  removePathPrefixesInPatch($patchName,$project,$bug); 

}

sub removePathPrefixesInPatch() {
	my $patchName=shift;
	my $project=shift;
	my $bug=shift;
	my $subdir="$project_$bug";

	open (FILEIN,"<$patchName")
		or die "Can't open $patchName";

	open (FILEOUT,">tmp.patch")
		or die "Can't open tmp.patch";

	my @lines = <FILEIN>;
	close FILEIN;

	my $lineNo=1;
	foreach $line (@lines) {
		if($lineNo==1) {
			my $relativePathBeg=index($line,$subdir);
			$relativePathBeg+=length($subdir);
			my $relativePathEnd=index($line,".java");
			$relativePathEnd+=length(".java");
			my $relativePath=substr($line,$relativePathBeg,$relativePathEnd-$relativePathBeg);

			print FILEOUT ("--- $relativePath\n");			
			print FILEOUT ("+++ $relativePath\n");			
		}
		elsif($lineNo==2) {
		}
		else {
			print FILEOUT "$line";
		}
		$lineNo++;
	}

	close(FILEOUT);
  	system("mv tmp.patch $patchName");  
}


sub computeRealLinesToRemove() {
#	my $source_ref=shift;
#	my $faulty_ref=shift;
#	my $sourceLineNo=shift;



	my ($source_ref, $faulty_ref, $sourceLineNo) = @_;


	$sourceLineNo--;

	my @source=@{$source_ref};
	my @faulty=@{$faulty_ref};

	my $indexSource=0;
	my $linesToRemove=0;
	
	print("Faulty: @faulty \n");
	
	
	$sourceLine=$source[$sourceLineNo++];
	@sourceLineCh=split("",$sourceLine);


	my $firstSourceLine=1;

	foreach $patchLine (@faulty) {
		@patchLineCh=split("",$patchLine);

		
		my $indexPatch=0;
		while($indexPatch<length($patchLine)) {
			my $blackCharPatch=0;
	#		print("patchLine: $patchLine");
			while($indexPatch<length($patchLine) && $blackCharPatch==0) {
#				print(" _ $indexPatch  _   ");

				if($patchLineCh[$indexPatch] eq " ") {
#					print("A$patchLineCh[$indexPatch]");
					$indexPatch++;
				}
				elsif($patchLineCh[$indexPatch] eq "\t") {
#					print("B$patchLineCh[$indexPatch]");
					$indexPatch++;
				}
				elsif($patchLineCh[$indexPatch] eq "\r") {
#					print("C$patchLineCh[$indexPatch]");
					$indexPatch++;
				}
				elsif($patchLineCh[$indexPatch] eq "\n") {
#					print("D");
					$indexPatch++;
				}
				else {
#					print("$patchLineCh[$indexPatch]    $indexPatch");
					$blackCharPatch=1;
				}
						
			}	

#			print("@sourceLineCh");
		
			my $blackCharSource=0;

			while($blackCharSource==0){
				if($indexSource==length($sourceLine)) {
					$indexSource=0;
					$sourceLine=$source[$sourceLineNo++];
					@sourceLineCh=split("",$sourceLine);
#					print("New source line!\n");
					$firstSourceLine=0;
				}
				while($indexSource<length($sourceLine) && $blackCharSource==0) {
#					print("Test: $firstSourceLine, $sourceLineCh[$indexSource] ne $patchLineCh[$indexPatch]\n"); 

					if($sourceLineCh[$indexSource] eq " ") {
						if($firstSourceLine==1) {
							$main::prefix = $main::prefix . $sourceLineCh[$indexSource]; 
						} 		
						$indexSource++;
					}
					elsif($sourceLineCh[$indexSource] eq "\t") {
						if($firstSourceLine==1) {
							$main::prefix = $main::prefix . $sourceLineCh[$indexSource]; 
						} 		
						$indexSource++;
					}
					elsif($sourceLineCh[$indexSource] eq "\r") {
						$indexSource++;
					}
					elsif($sourceLineCh[$indexSource] eq "\n") {
						$indexSource++;
						$linesToRemove++;
					}
					elsif(($sourceLineCh[$indexSource] ne $patchLineCh[$indexPatch]) 
					&& $indexSource+1<length($sourceLine) 
					&& $sourceLineCh[$indexSource] eq "/"
					&& $sourceLineCh[$indexSource+1] eq "/") {
						$indexSource=length($sourceLine);
						$linesToRemove++;
						print("comment\n");
					}
					elsif($firstSourceLine==1  
					&& ($sourceLineCh[$indexSource] ne $patchLineCh[$indexPatch])) {  
						$main::prefix = $main::prefix . $sourceLineCh[$indexSource]; 
						$indexSource++;
						print("prefix append");	
					}
					else {
#						print("!!!!!!!!!!!!!!!!!\n");
						$blackCharSource=1;
					}
				}
			}

			if($blackCharSource==1 && $blackCharPatch==1) {
			
				if($sourceLineCh[$indexSource] ne $patchLineCh[$indexPatch]) {
					print("Error: patch not consistent with the source code at line $sourceLineNo. Found:  $sourceLineCh[$indexSource] Expected: $patchLineCh[$indexPatch] at position $indexSource ($indexPatch in patch");
					exit;			
				}
#				else {
#					print("^$sourceLineCh[$indexSource] $patchLineCh[$indexPatch]^");
#				}
				$blackCharSource=0;
				$blackCharPatch=0;
				$indexSource++;
				$indexPatch++;



			}

 

		
		}
	}
	print("Lines to remove from source: $linesToRemove\n");
	return $linesToRemove;
}
