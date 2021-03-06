#!/usr/bin/perl
use strict;
use warnings;
use Bio::SeqIO;


my ($outdir,$dir,$bl2g,$pep,$ref,$genewise,$trans)=@ARGV;
die "perl $0 outdir blast2geneDIR *bl2g *protein *ref *genewise *trans\n" if (scalar(@ARGV) != 7);

my %seq;
my %bl2g;

my $pepfa=Bio::SeqIO->new(-format=>"fasta",-file=>"$pep");
while (my $seq=$pepfa->next_seq) {
    my $id=$seq->id;
    my $seq=$seq->seq;
    $seq{$id}=$seq;
}

$bl2g=~/([^\/]+)\.tblastn.bp.bl2g.tophit/;
my $species=$1;
open (F,"$bl2g") or die "Cannot open $bl2g\n";
while (<F>) {
    chomp;
    my @a=split(/\t/,$_);
    next if /^#/;
    $bl2g{$a[1]}{$a[2]}{start}=$a[3];
    $bl2g{$a[1]}{$a[2]}{end}=$a[4];
    $bl2g{$a[1]}{$a[2]}{stand}=$a[5];
}
close F;
exit if (! %bl2g);
my $out="$outdir/run/02.homolog.03.genewise_run";
`mkdir $out` if (! -e "$out");
open (SH,">$out/$species.sh")||die"$!\n$out/$species.sh\n";
my $reffa=Bio::SeqIO->new(-format=>"fasta",-file=>"$ref");
while (my $seq=$reffa->next_seq) {
    my $chrid=$seq->id;
    my $chrseq=$seq->seq;
    my $chrlen=length($chrseq);
    if (exists $bl2g{$chrid}){
        my $dir2="$dir/$species";
        `mkdir $dir2` if (! -e "$dir2");
        for my $id (sort keys %{$bl2g{$chrid}}){
            my $dir3="$dir2/$chrid-$id";
            `mkdir $dir3` if (! -e "$dir3");
            my $seqid=$id;
            my $chrstart=$bl2g{$chrid}{$id}{start};
            my $newchrstart=$chrstart-200;
            $newchrstart=1 if $newchrstart<1;
            my $chrend=$bl2g{$chrid}{$id}{end};
            my $newchrend=$chrend+200;
            $newchrend=$chrlen if $newchrend>$chrlen;
            my $chrstand=$bl2g{$chrid}{$id}{stand};
            my $newseq=substr($chrseq,$newchrstart-1,$newchrend-$newchrstart+1);
            open (O,">$dir3/subseq.txt");
            print O "#ID\tChr\tSeq\tChr_start\tChr_end\tNewChr_Start\tNewChr_end\n";
            print O "$id\t$chrid\t$seqid\t$chrstart\t$chrend\t$newchrstart\t$newchrend\n";
            close O;
            open (O,">$dir3/protein.fa")||die"$!";
            print O ">$seqid\n$seq{$seqid}\n";
            close O;
            open (O,">$dir3/dna.fa")||die"$!";
            print O ">$chrid\n$newseq\n";
            close O;
            print SH "$genewise -$chrstand -gff $dir3/protein.fa $dir3/dna.fa > $dir3/genewise.gff ; $trans $dir3/genewise.gff\n";
        }
    }
}
close SH;

