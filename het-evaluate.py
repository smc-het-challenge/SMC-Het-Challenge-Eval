#!/usr/bin/env python

"""
Code to run challenge workflows
"""

import os
import uuid
import json
import shutil
import argparse
import subprocess
import logging
from glob import glob
from xml.dom.minidom import parseString as parseXML
import tarfile
from StringIO import StringIO

"""
Code for dealing with XML
"""

def getText(nodelist):
    rc = []
    for node in nodelist:
        if node.nodeType == node.TEXT_NODE:
            rc.append(node.data)
    return ''.join(rc)


def dom_scan(node, query):
    stack = query.split("/")
    if node.localName == stack[0]:
        return dom_scan_iter(node, stack[1:], [stack[0]])

def dom_scan_iter(node, stack, prefix):
    if len(stack):
        for child in node.childNodes:
            if child.nodeType == child.ELEMENT_NODE:
                if child.localName == stack[0]:
                    for out in dom_scan_iter(child, stack[1:], prefix + [stack[0]]):
                        yield out
                elif '*' == stack[0]:
                    for out in dom_scan_iter(child, stack[1:], prefix + [child.localName]):
                        yield out
    else:
        if node.nodeType == node.ELEMENT_NODE:
            yield node, prefix, dict(node.attributes.items()), getText( node.childNodes )
        elif node.nodeType == node.TEXT_NODE:
            yield node, prefix, None, getText( node.childNodes )

def tool_dir_scan(tool_dir):
    for tool_conf in glob(os.path.join(os.path.abspath(tool_dir), "*.xml")) + glob(os.path.join(os.path.abspath(tool_dir), "*", "*.xml")):
        logging.info("Scanning: " + tool_conf)
        dom = parseXML(tool_conf)
        s = dom_scan(dom.childNodes[0], "tool")
        if s is not None:
            docker_tag = None
            scan = dom_scan(dom.childNodes[0], "tool/requirements/container")
            if scan is not None:
                for node, prefix, attrs, text in scan:
                    if 'type' in attrs and attrs['type'] == 'docker':
                        docker_tag = text
                        
            yield list(s)[0][2]['id'], tool_conf, docker_tag
    


def command_run(args):
    
    ga_files = glob(os.path.join(args.entry_dir, "*.ga"))
    assert(len(ga_files) == 1)

    input_json = {
      "VCF_INPUT" : {
        "class" : "File",
        "path" : os.path.abspath(args.tumor_base + ".mutect.vcf")
      },
      "CNA_INPUT" : {
        "class" : "File",
        "path" : os.path.abspath(args.tumor_base + ".battenberg.txt")
      },
      "sample" : "Tumour"  
    }
    
    if not os.path.exists(args.workdir):
        os.mkdir(args.workdir)
    input_path = os.path.join(args.workdir, "input.json")
    with open( input_path, "w") as handle:
        handle.write(json.dumps(input_json))
    
    eval_tool_dir = os.path.join(args.workdir, "eval_tool_copy")
    if not os.path.exists(eval_tool_dir):
        os.mkdir(eval_tool_dir)
    
    with open(os.path.join(eval_tool_dir, "smc_het_eval.xml"), "w") as handle:
        handle.write(EVAL_COPY_TOOL)
    
    cmd = [
        "gwftool", "--no-net", 
        "-t", args.entry_dir, 
        "-t", eval_tool_dir, 
        "-w", args.workdir, 
        ga_files[0], input_path, 
        "-o", args.outdir
    ]
    print "Running: %s" % (" ".join(cmd))
    subprocess.check_call(cmd)

def galaxy_tool_prefix_docker(xml_text, new_prefix):
    dom = parseXML(xml_text)
    scan = dom_scan(dom.childNodes[0], "tool/requirements/container")
    if scan is not None:
        for node, prefix, attrs, text in scan:
            if 'type' in attrs and attrs['type'] == 'docker':
                new_tag = "%s/%s" % (new_prefix, node.childNodes[0].data)
                print "changing %s to %s" % (node.childNodes[0].data, new_tag)                
                node.childNodes[0].data = new_tag #"%s/%s" % (new_prefix, node.childNodes[0].data)
                #docker_tag = text
    #print dom
    return dom.toxml()

def command_rename(args):
    entry_id = os.path.basename(os.path.abspath(args.entry))
    
    out_dir = os.path.join(os.path.abspath(args.entry), "repack")
    
    if not os.path.exists(out_dir):
        os.mkdir(out_dir)

    ga_file = glob(os.path.join(args.entry, "*.ga"))[0]
    shutil.copy(ga_file, os.path.join(out_dir, os.path.basename(ga_file)))
        
    for tool_file in glob(os.path.join(args.entry, "*.tar.gz")):
        print tool_file
        in_tools = tarfile.open(tool_file)
        out_tools = tarfile.open(os.path.join(out_dir, os.path.basename(tool_file)), "w|gz")
        for member in in_tools.getmembers():
            if member.name.endswith(".xml"):
                handle = in_tools.extractfile(member)
                xml_text = handle.read()
                xml_out = galaxy_tool_prefix_docker(xml_text, entry_id)
                member.size = len(xml_out)
                out_tools.addfile(member, StringIO(xml_out))
            else:
                out_tools.addfile(member, in_tools.extractfile(member))
        out_tools.close()
        in_tools.close()
        #resources.add_tool_package(tool_file, {"entry" : entry_id})
    for image_file in glob(os.path.join(args.entry, "*.tar")):
        print image_file
        in_image = tarfile.open(image_file)
        out_image = tarfile.open(os.path.join(out_dir, os.path.basename(image_file)), "w")
        for member in in_image.getmembers():
            print "found", member.name
            if member.name == "repositories":
                handle = in_image.extractfile(member)
                json_text = handle.read()
                meta = json.loads(json_text)
                out = {}
                for k,v in meta.items():
                    out[ "%s/%s" % (entry_id, k) ] = v
                out_text = json.dumps(out)
                member.size = len(out_text)
                out_image.addfile(member, StringIO(out_text))
            elif member.name == "manifest.json":
                handle = in_image.extractfile(member)
                json_text = handle.read()
                meta = json.loads(json_text)
                for elem in meta:
                    if "RepoTags" in elem:
                        out = []
                        for i in elem["RepoTags"]:
                            out.append( "%s/%s" % (entry_id, i) )
                        elem["RepoTags"] = out
                out_text = json.dumps(meta)
                member.size = len(out_text)
                out_image.addfile(member, StringIO(out_text))
            else:
                out_image.addfile(member, in_image.extractfile(member))
        out_image.close()
        in_image.close()
        #resources.add_docker_image_file(image_file, { "entry" : entry_id })

def command_unpack(args):
    for tool_file in glob(os.path.join(args.entry, "*.tar.gz")):
        subprocess.check_call(["tar", "xvzf", os.path.basename(tool_file)], cwd=args.entry)
    for docker_image in glob(os.path.join(args.entry, "*.tar")):
        subprocess.check_call(["docker", "load", "-i", docker_image])
        


EVAL_COPY_TOOL = """<tool id="smc_het_eval" name="SMC-Het Evaluator" version="0.1.0">
  <stdio>
    <exit_code range="1:" />
  </stdio>
  <requirements>
    <container type="docker">ipython/scipystack</container>
  </requirements>
  <command><![CDATA[

#if $cellularity.submit == 'yes':
cp ${cellularity.predfile} cellularity.predfile ;
#end if
#if $population.submit == 'yes':
cp ${population.predfile} population.predfile ;
#end if
#if $proportion.submit == 'yes':
cp ${proportion.predfile} proportion.predfile ;
#end if
#if $cluster_assignment.submit == 'yes':
cp ${cluster_assignment.predfile} cluster_assignment.predfile ;
#end if
#if $cocluster_assignment.submit == 'yes':
cp ${cocluster_assignment.predfile} cocluster_assignment.predfile ;
#end if
#if $cluster_assignment.submit == 'yes' and $cluster_assignment.phylogeny.submit == 'yes':
cp ${cluster_assignment.predfile} cluster_assignment.predfile ;
cp ${cluster_assignment.phylogeny.predfile} cluster_assignment.phylogeny.predfile ;
#end if
#if $cocluster_assignment.submit == 'yes' and $cocluster_assignment.ancestor.submit == 'yes':
cp ${cocluster_assignment.predfile} cocluster_assignment.predfile ;
cp ${cocluster_assignment.ancestor.predfile} cocluster_assignment.ancestor.predfile ;
#end if


tar cvzf $outfile
#if $cellularity.submit == 'yes':
cellularity.predfile
#end if
#if $population.submit == 'yes':
population.predfile
#end if
#if $proportion.submit == 'yes':
proportion.predfile
#end if
#if $cluster_assignment.submit == 'yes':
cluster_assignment.predfile
#end if
#if $cocluster_assignment.submit == 'yes':
cocluster_assignment.predfile
#end if
#if $cluster_assignment.submit == 'yes' and $cluster_assignment.phylogeny.submit == 'yes':
cluster_assignment.predfile
cluster_assignment.phylogeny.predfile
#end if
#if $cocluster_assignment.submit == 'yes' and $cocluster_assignment.ancestor.submit == 'yes':
cocluster_assignment.predfile
cocluster_assignment.ancestor.predfile
#end if
    ]]></command>
  <inputs>
      
      <!-- param name="sample" type="select" label="Sample" help="Testing Sample">
        <options from_file="smc_samples.loc">
          <column name="value" index="1" />
          <column name="name" index="0" />
        </options>
      </param -->
      
      <conditional name="cellularity">
        <param type="select" name="submit" label="Submit Cellularity File" help="Input for Challenge 1A">
          <option value="yes">Yes</option>
          <option value="no" selected="True">No</option>
        </param>
        <when value="yes">
          <param name="predfile" type="data" format="txt" label="Predicted Cellularity File"/>
        </when>
      </conditional> 
      
      <conditional name="population">
        <param type="select" name="submit" label="Submit Population File" help="Input for Challenge 1B">
          <option value="yes">Yes</option>
          <option value="no" selected="True">No</option>
        </param>
        <when value="yes">
          <param name="predfile" type="data" format="txt" label="Predicted Population File"/>
        </when>
      </conditional> 
      
      <conditional name="proportion">
        <param type="select" name="submit" label="Submit  Proportion File" help="Input for Challenge 1C">
          <option value="yes">Yes</option>
          <option value="no" selected="True">No</option>
        </param>
        <when value="yes">
          <param name="predfile" type="data" format="txt" label="Predicted Proportion File"/>
        </when>
      </conditional> 
      
      <conditional name="cluster_assignment">
        <param type="select" name="submit" label="Submit Assignment File" help="Input for Challenge 2A">
          <option value="yes">Yes</option>
          <option value="no" selected="True">No</option>
        </param>
        <when value="yes">
          <param name="predfile" type="data" format="txt" label="Cluster Assignment File"/>
          
          <conditional name="phylogeny">
            <param type="select" name="submit" label="Submit Phylogeny Matrix" help="Input for Challenge 3A">
              <option value="yes">Yes</option>
              <option value="no" selected="True">No</option>
            </param>
            <when value="yes">
              <param name="predfile" type="data" format="txt" label="Phylogeny Matrix"/>
            </when>
          </conditional>
        </when>
      </conditional> 


      <conditional name="cocluster_assignment">
        <param type="select" name="submit" label="Submit Co-clustering Matrix" help="Input for Challenge 2B">
          <option value="yes">Yes</option>
          <option value="no" selected="True">No</option>
        </param>
        <when value="yes">
          <param name="predfile" type="data" format="txt" label="Co-clustering Matrix"/>
          
          <conditional name="ancestor">
            <param type="select" name="submit" label="Submit Ancestor Matrix" help="Input for Challenge 3B">
              <option value="yes">Yes</option>
              <option value="no" selected="True">No</option>
            </param>
            <when value="yes">
              <param name="predfile" type="data" format="txt" label="Ancestor Matrix"/>
            </when>
          </conditional>
        </when>
      </conditional> 
  </inputs>
  <outputs>
      <data name="outfile" format="data" label="Evaluation Scores"/>
  </outputs>  

  <help><![CDATA[
      TODO: Fill in help.
]]></help>
</tool>
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(title="subcommand")
    
    parser_run = subparsers.add_parser('run')
    parser_run.add_argument("--workdir", default="work")
    parser_run.add_argument("tumor_base")
    parser_run.add_argument("entry_dir")
    parser_run.add_argument("outdir")
    parser_run.set_defaults(func=command_run)

    parser_rename = subparsers.add_parser('docker-rename')
    parser_rename.add_argument("entry")
    parser_rename.set_defaults(func=command_rename)
    
    parser_unpack = subparsers.add_parser('unpack')
    parser_unpack.add_argument("entry")
    parser_unpack.set_defaults(func=command_unpack)
    
    args = parser.parse_args()
    args.func(args)

