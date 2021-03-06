
Tail Tools
==========

This is a Python 2 based suite of tools for analysing Illumina or SOLiD sequencing reads with poly(A) tails, as produced using the PAT-Seq technique. The PAT-Seq technique was developed by Dr. Traude Beilharz, who heads the RNA Systems Biology Laboratory at Monash University.

Tail Tools is developed by Dr. Paul Harrison (paul.harrison@monash.edu) at Monash University. Development was initially under the auspices of the Victorian Bioinformatics Consortium and now continues with the Monash Bioinformatics Platform. Michael See contributed R code to visualize output as an interactive heatmap.

Please feel free to email Paul any questions you have about getting Tail Tools up and running.

Links

* [Tail-tools in the PYthon Package Index](https://pypi.python.org/pypi/tail-tools/)
* [RNA Systems Biology Laboratory](http://rnasystems.erc.monash.edu)
* [Monash Bioinformatics Platform](http://monash.edu/bioinformatics)

License
-------

This software is distributed under the terms of the GPL, version 2 or later,
excepting that:

- The third party javascript libraries included for convenience
  in directory tail_tools/web/third_party are covered by the terms of
  their respective licenses (also in that directory).

- The remaining files in the directory tail_tools/web are placed in the
  public domain.


Requirements
------------

Use of PyPy is recommened for speed.

- [nesoni](https://github.com/Victorian-Bioinformatics-Consortium/nesoni), most easy installed with pip:

    pip install nesoni

  You don't need to install all of nesoni's dependencies, just Python 2.7 or later or PyPy. Do be sure to install the R component of nesoni.

- bowtie2 for Illumina reads or SHRiMP for SOLiD reads

- samtools

- The "convert" tool from ImageMagick.

- rsync (for downloads from UCSC browser)

- R, with package "seriation" and BioConductor packages "limma" and "edgeR", and ["varistran"](https://github.com/MonashBioinformaticsPlatform/varistran)

- [Fitnoise](https://github.com/pfh/fitnoise) for differential testing.

- [degust.py](https://victorian-bioinformatics-consortium.github.io/degust/dist/latest/degust.py)



Optional:

- [SplitsTree](http://www.splitstree.org/)
  Note: v4.13.1 seems to be broken, v4.11.3 works


Installation
------------

Easy way:

    pip install --upgrade tail-tools

Bleeding edge github version with pip:

    pip install --upgrade 'git+https://github.com/Victorian-Bioinformatics-Consortium/tail-tools.git#egg=tail-tools'

From source:

    python setup.py install

For PyPy it seems to be currently easiest to set up in a virtualenv:

    virtualenv -p pypy myenv
    pip install --upgrade 'git+https://github.com/Victorian-Bioinformatics-Consortium/tail-tools.git#egg=tail-tools'


### R library installation

Tail Tools includes an R package. This isn't essential to run the pipeline, but contains functions to produce various Shiny reports. It can be installed from R with:

Easy way:

    R
    devtools::install_github("Victorian-Bioinformatics-Consortium/tail-tools", subdir="tail_tools")

From source:

    R
    devtools::install("tail_tools")


Usage
-----

This package contains a number of tools, which can be listed by typing:

    tail-tools
  

The package can be used directly from the source directory with:

    python -m tail_tools


These tools may also be used from a python script (using the same system as my older genomics python package "nesoni"). A typical example of invoking the pipeline from python can be found below.


### R library usage

The tailtools R library can then be loaded in R with:

    library(tailtools)

* [Manual (pdf)](http://rnasystems.erc.monash.edu/doc/tailtools.pdf)

The pipeline also includes a Shiny app as part of its output (in subdirectory "shiny"). This can be served with ShinyServer or viewed from within R with `shiny::runApp("pipelineoutputdir/shiny")`.


Reference format
----------------

Before processing any reads, you need to create a "tail-tools reference directory".

References are most easily downloaed from the UCSC browser or the Ensembl genome browser.

References can be downloaded from the UCSC browser using:

    tail-tools make-ucsc-reference: \
        <output_dir> \
        <ucsc_reference_name>

References can also be downloaded from the Ensembl genome browser using "tail-tools make-ensembl-reference". The Ensembl genome annotations are more comprehensive, but using them requires specifying more parameters. Type "tail-tools make-ensembl-reference" for more instructions, or email Paul.

If creating your own reference, it needs to consist of:

- sequences, eg in FASTA format
- annotations in GFF3 format

The reference directory is then created with the command:

    tail-tools make-tt-reference: \
        <output_dir> \
        <sequence_file> \
        <annotations_file>

Annotations shall include the following feature types and attributes:

gene
* ID - unique identifier
* Name (optional) - nomenclature name
* Product (optional) - short description
* Biotype (optional) - what type of gene it is (protein_coding, rRNA, etc)

mRNA
* ID      - unique identifier
* Parent  - gene ID

CDS
* Parent  - mRNA ID

exon
* Parent  - mRNA ID


The pipeline assumes that genes do not have overlapping exons on the same strand. Is this too much to ask for in a reasonable genome annotation? Apparently the answer is yes. The UCSC and Ensemble genome downloaders merge genes with overlapping exons -- ids and names are concatenated with "/" as a separator. This can complicate downstream analysis, and Paul apologises for the pain this causes.



Pipeline
--------

Having created a reference directory, the next step is to run the pipeline,
"analyse-polya-batch". This can be done from the command line, but is more
usefully done from a python script. We suggest adapting the following example
to your data:

```python

import tail_tools, nesoni, glob

tags = [
    ('wt1',   ['wt','rep1']),
    ('wt2',   ['wt','rep2']),
    ('wt3',   ['wt','rep3']),
    ('mutA1', ['mutA','rep1']),
    ('mutA2', ['mutA','rep2']),
    ('mutA3', ['mutA','rep3']),
    ('mutB1', ['mutB','rep1']),
    ('mutB2', ['mutB','rep2']),
    ('mutB3', ['mutB','rep3']),
]

# Where to find FASTQ files. %s becomes the name of the sample. Wildcards * and ? may be used.
filename_pattern = 'raw_data/%s.fastq.gz'

# For each sample we create a tail_tools.Analyse_polya instance
# Each sample is given a set of tags
samples = [ ]
for name, tags in tags:
    reads = sorted(glob.glob(filename_pattern % name))    
    assert reads, 'No reads for '+name
    
    samples.append(tail_tools.Analyse_polya(
        name,
        reads = reads,
        tags = tags,
        
        #To adjust clipping prior to alignment, modify these defaults:
        # clip_runs_basespace = tail_tools.Clip_runs_basespace(
        #    adaptor='AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC', 
        #    clip_quality=0, length=20),
        
        #To allow for looser mispriming, lower this.
        #To only allow for stricter mispriming, raise this (maximum 1).
        #extension_prop_a = 0.6
        ))


action = tail_tools.Analyse_polya_batch(
        # Output directory
        'pipeline',
        
        # Title for report
        title = 'Pipeline output',
        
        # Reference directory you created earlier
        reference = '/path/to/reference/directories/S_cerevisiae_82',
        
        # Allow reads/peaks this far downstrand of 
        # the annotated transcript end point
        # (however extension will not continue into CDS on the same strand)
        # For yeast use 400, for sparser genomes than yeast use 2000
        # (Left blank since it's easy to forget to change.)
        extension = ... ,
        
        # Size of peak features generated
        # ie how far back from a site a read can end and still be counted towards it
        # Should be read length or a little shorter
        peak_length = 300,
        
        # Minimum average tail length required to call a peak.
        # Set higher then 0.0 if there is mispriming.
        # 15.0 may be reasonable.
        peak_min_tail = ...,
        
        # Optional: Species to use in GO term analysis, choices are: Sc Ce Mm Hs
        species="Sc",
                
        # List of instances of tail_tools.Analyse_polya
        samples = samples,
        
        # List of sample groups
        # A sample group is specified as 
        # '<nesoni-selection-expression>=<name>'
        # (=<name> may be omitted)
        # See nesoni help for description of selection expressions,
        # this uses the tags given to each sample to concisely 
        # specify sets of samples.
        groups = [ 'wt', 'mutA', 'mutB' ],
        
        # (Advanced)
        # Perform differential tests
        tests = [
            tail_tools.Test(
                'mutA-wt',
                title = 'Mutant A vs wildtype',
                null  = ['wt/mutA'],
                alt   = ['mutA'],
                ),
            #etc
            ],
        )



# A little boilerplate so that
# - multiprocessing works
# - you can control making
#   (see nesoni help on --make-* flags)

def main():
    action.make()

if __name__ == '__main__': 
    nesoni.run_script(main)

# If run again with adjusted parameters,
# only the parts that need to be run again will run.
#
# To force a complete re-run:
#     python myscript.py --make-do all
#
# To re-run everything but the alignment to reference
# (eg if there is a new version of tail-tools)
#     python myscript.py --make-do all --make-done analyse-polya
#

```

BAM-file alignment attributes
---

* [BAM-file alignment attributes](doc/bam-files.md)


Pipeline output
---

* [Directories and files produced by the pipeline](doc/output.md)

Statistics
---

* [Statistics produced by `tail-tools analyse-tail-counts:`](doc/statistics.md)
* [Differential expression and tail length](doc/differential.md)






