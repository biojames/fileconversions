#!/usr/bin/perl

use strict;

sub process_data {

  my @data=();
  my @dataalt=();
  my %used=();

  my @wells=();

  #reorientation matrix because the reads are column-wise but plates are often set up row-wise
  my @col2row=(0,1);  #first element is time, second is temperature
  for (my $ROW=0; $ROW<8; $ROW++) {
    for (my $COL=0; $COL<12; $COL++) {
      push(@col2row,$COL*8+$ROW+2);
      push(@wells,pack("C",$ROW+65).sprintf("%d",$COL+1));
    }
  }

  my $wellheading="";
  for (my $i=0; $i<@col2row; $i++) {
    $wellheading.=$wells[$i]."\t";
  }

  my $o=join(" ",@col2row);
  while ($o=~s/^(.{80})//) { print STDERR $1."\n" }

  my $file="dE_$$";
  if ($_[1] ne "") {
    $file=$_[1];
  }

  open(I,$_[0]) || die "File $_[0] not found\n";
  my $temperature=-1.0;
  my $line=-1;
  my $t=0;
  while ($_=<I>) {
    $line++;
    if (($line < $_[2])||($line > $_[3])) { next; }
    #2017-05-08 17:15:09  Thread Id 5520: RAW
    if ($_=~/(\d+)\-(\d+)\-(\d+)\s+(\d+)\:(\d+)\:(\d+)\s+Thread.+RAW/) {
      $t=$3*86400+$4*3600+$5*60+$6;
    } elsif ($_=~/CMSG_ISTTEMP.+Data.\s*(\d+)/) {
      print STDERR "@@@";
      $temperature=$1/10;
      print STDERR $temperature;
    } elsif ($_=~/^Channel\s(\d+)\s*\-\s*(\S[\-\d\s]+)$/) {
      print STDERR "+++";
      my $channel=$1;
      my $line=$2;
      my @dat=split(/\s+/,$line);
      if ($used{"$channel-$t"}>0) {
        if (!exists($dataalt[$channel])) { $dataalt[$channel]=[]; print STDERR "." }
        push(@{$dataalt[$channel]},[($t,$temperature,@dat)]);
        $used{"$channel-$t"}++;
        #print STDERR "$t,".$used{"$channel-$t"}.": ".substr($_,0,20)."\n";
      } else {
        if (!exists($data[$channel])) { $data[$channel]=[]; print STDERR "." }
        push(@{$data[$channel]},[($t,$temperature,@dat)]);
        $used{"$channel-$t"}=1;
      }
    }
  }

  printf STDERR "Loaded %d channels.\n", scalar @data;

  #remove time offset
  for (my $C=0; $C<scalar @data; $C++) {
    #skip first row with starting time
    for (my $i=1; $i<scalar @{$data[$C]}; $i++) {
      $data[$C]->[$i]->[0] -= $data[$C]->[0]->[0];
    }
    $data[$C]->[0]->[0] = 0;
  }

  my $header="Temperature\tTime\t".$wellheading; #join("\t",@wells);

  my $ch0=$data[0]->[0];
  my @includecol = ();
  for (my $jj=0; $jj<scalar @{$ch0}; $jj++) {
    push(@includecol,0);
  }
  for (my $C=0; $C<scalar @data; $C++) {
    for (my $i=0; $i<scalar @{$data[$C]}; $i++) {
      $ch0=$data[$C]->[$i];
      for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
        my $j=$col2row[$jj];
        if ($dataalt[0]->[$i]->[$j]!=0) { $includecol[$j]=1 }
      }
    }
  }

  open(O,">".$file."-all-1-includecols.txt");
  for (my $C=0; $C<scalar @data; $C++) {
    print O "CHANNEL $C\n";
    print O "Temperature\tTime\t";
    for (my $j=0; $j<@wells; $j++) {
      if ($includecol[$col2row[$j+2]] == 1) {
        print O "$wells[$j]\t";
      }
    }
    print O "\n";
    for (my $i=0; $i<scalar @{$data[$C]}; $i++) {
      my $ch0=$data[$C]->[$i];
      print O $ch0->[1]."\t".$ch0->[0]."\t";  #time and temperature
      for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
        my $j=$col2row[$jj];
        if ($includecol[$j] == 1) {
          if ($dataalt[0]->[$i]->[$j]==0) { print O "*" }
          printf O "%0.4f\t",$ch0->[$j];
        }
      }
      print O "\n";
    }
    print O "\n";
  }
  close(O);


  open(O,">".$file."-all-1.txt");
  for (my $C=0; $C<scalar @data; $C++) {
    print O "CHANNEL $C\n$header\n";
    for (my $i=0; $i<scalar @{$data[$C]}; $i++) {
      my $ch0=$data[$C]->[$i];
      print O $ch0->[1]."\t".$ch0->[0]."\t";
      for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
        my $j=$col2row[$jj];
        if ($dataalt[0]->[$i]->[$j]==0) { print O "*" }
        printf O "%0.4f\t",$ch0->[$j];
      }
      print O "\n";
    }
    print O "\n";
  }
  close(O);

  open(O,">".$file."-all-2.txt");
  for (my $C=0; $C<scalar @dataalt; $C++) {
    print O "CHANNEL $C\n$header\n";
    for (my $i=0; $i<scalar @{$dataalt[$C]}; $i++) {
      my $ch0=$dataalt[$C]->[$i];
      print O $ch0->[1]."\t".$ch0->[0]."\t";
      for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
        my $j=$col2row[$jj];
        if ($dataalt[0]->[$i]->[$j]==0) { print O "*" }
        printf O "%0.4f\t",$ch0->[$j];
      }
      print O "\n";
    }
    print O "\n";
  }
  close(O);


  #foreach $c (@data) {
  #  for (my $i=0; $i<@times; $i++) {
  #    print $times[$i]."\t".join("\t",@{$c->[$i]})."\n";
  #  }
  #}

  #dataalt is used to determine those parts not set up in template
  open(O,">".$file."-ratio41-1.txt");
  print O "$header\n";
  for (my $i=0; $i<scalar @{$data[0]}; $i++) {
    my $ch0=$data[0]->[$i];
    my $ch3=$data[3]->[$i];
    print O $ch0->[1]."\t".$ch0->[0]."\t";
    for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
      my $j=$col2row[$jj];
      if ($dataalt[0]->[$i]->[$j]==0) { print O "*" }
      if (($ch0->[$j] != 0) && ($ch3->[$j] != 0)) {
        printf O "%0.4f\t",($ch3->[$j])/($ch0->[$j]);
      } else {
        printf O "\t";
      }
    }
    print O "\n";
  }
  close(O);


  open(O,">".$file."-ratio41-2.txt");
  print O "$header\n";
  for (my $i=0; $i<scalar @{$dataalt[0]}; $i++) {
    my $ch0=$dataalt[0]->[$i];
    my $ch3=$dataalt[3]->[$i];
    print O $ch0->[1]."\t".$ch0->[0]."\t";
    for (my $jj=2; $jj<scalar @{$ch0}; $jj++) {
      my $j=$col2row[$jj];
      if ($dataalt[0]->[$i]->[$j]==0) { print O "*" }
      if (($ch0->[$j] != 0) && ($ch3->[$j] != 0)) {
        printf O "%0.4f\t",($ch3->[$j])/($ch0->[$j]);
      } else {
        printf O "\t";
      }
    }
    print O "\n";
  }
  close(O);

}

open(I,$ARGV[0]) || die "File $ARGV[0] not found.\n";

my @ranges=();

my $line=0;
my $start=-1;
while ($_=<I>) {
  if ($_=~/Abl.Load.Program/) {
    $start=$line;
  } elsif ($_=~/Assay.\'([^\']+)\':.Run.finished./) {
    push(@ranges,[$start,$line,$1]);
    $start=-1;
  }
  $line++;
}
close(I);

foreach my $r (@ranges) {
  my $s="Processing $ARGV[0] assay $r->[2] between lines $r->[0] and $r->[1]";
  my $ss=$s;
  $ss=~s/./#/g;
  print STDERR "##$ss##\n# $s #\n##$ss##\n";
  &process_data($ARGV[0],$r->[2],$r->[0],$r->[1]);
}


