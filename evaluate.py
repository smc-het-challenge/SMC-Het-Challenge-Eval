#!/usr/bin/env python

"""
Code to run challenge workflows
"""

import os
import uuid
import json
import shutil
import argparse
import logging
import nebula
import nebula.galaxy
import nebula.deploy
import nebula.docstore
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
    workflow = nebula.galaxy.GalaxyWorkflow(ga_file=ga_files[0])
    
    eval_uuid = None
    for s in workflow.steps():
        if s.tool_id == 'smc_het_eval':
            print s.tool_id, s.uuid
            eval_uuid = s.uuid
    print "Eval Step: %s" % (eval_uuid)
    
    ds = nebula.docstore.FileDocStore(args.agro)
    #ds = nebula.docstore.AgroDocStore(args.agro, "workdir")
    
    input_data = {}
    for t, meta in ds.filter(type="testing_input", tumor_name=args.tumor_name):
        if meta['file_type'] == 'cna':
            input_data['CNA_INPUT'] = {
                "uuid" : t
            }
        if meta['file_type'] == 'vcf':
            input_data['VCF_INPUT'] = {
                "uuid" : t
            }
    print input_data
    
    resources = nebula.galaxy.GalaxyResources()
    
    #add in the testing tool
    resources.add_tool_package("smc_het_evalcopy.tar.gz")
    for tool_file in glob(os.path.join(args.entry_dir, "*.tar.gz")):
        resources.add_tool_package(tool_file, {"entry" : args.entry_name})
    for image_file in glob(os.path.join(args.entry_dir, "*.tar")):
        resources.add_docker_image_file(image_file, { "entry" : args.entry_name })

    resources.sync(ds)
    
    engine = nebula.galaxy.GalaxyEngine(
        docstore=ds, resources=resources,
        child_network="none",
        work_volume=os.path.abspath("./galaxy_work")
    ) #, hold=True)
    
    task = nebula.galaxy.GalaxyWorkflowTask(
            engine, workflow,
            inputs=input_data,
            step_tags={
                eval_uuid : {
                    "outfile" : [ "result_tar" ]
                }
            },
            tags = [ "entry:%s" % args.entry_name, "tumor:%s" % args.tumor_name ]
    )
    
    print json.dumps(task.to_dict(), indent=4)
    
    deploy = nebula.deploy.CmdLineDeploy()
    results = deploy.run(task)

def command_extract(args):
    ds = nebula.docstore.FileDocStore(args.agro)
    #ds = nebula.docstore.AgroDocStore(args.agro, "workdir")
    if not os.path.exists(args.out):
        os.mkdir(args.out)
    for t, meta in ds.filter(type='file'):
        if 'job' in meta and meta['job']["tool_id"] == "smc_het_eval":
            tumor = None
            entry = None
            for tag in meta['tags']:
                if tag.startswith("tumor:"):
                    tumor = tag.split(":")[1]
                if tag.startswith("entry:"):
                    entry = tag.split(":")[1]
            if tumor is not None and entry is not None:
                if not os.path.exists(os.path.join(args.out, tumor)):
                    os.makedirs(os.path.join(args.out, tumor))
                print t, meta.get('name', 'NA'), meta['tags'], meta['state']
                if meta['state'] == "ok" and ds.size(nebula.Target(t)) > 0:
                    f = ds.get_filename(nebula.Target(t))
                    print "Copying entry %s %s to %s" % (entry, tumor, f)
                    shutil.copy( f, os.path.join(args.out, tumor, entry + ".tar.gz") )
                else:
                    print "searching", entry
                    with open( os.path.join(args.out, tumor, entry + ".error_log" ), "w" ) as handle:
                        for i, meta2 in ds.filter(type='file', tags=["entry:%s" % entry]):
                            if "tumor:%s" % (tumor) in meta2['tags']:
                                if meta2['state'] == 'error':
                                    handle.write("Tool:%s : STDOUT\n" % meta2['job']['tool_id'])
                                    handle.write("%s\n" % (meta2['job']['stdout']))
                                    handle.write("Tool:%s : STDERR\n" % meta2['job']['tool_id'])
                                    handle.write("%s\n" % (meta2['job']['stderr']))

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

def command_loadinputs(args):
    ds = nebula.docstore.FileDocStore(args.agro)
    #ds = nebula.docstore.AgroDocStore(args.agro, "workdir")
    vcf_uuid = str(uuid.uuid4())
    cna_uuid = str(uuid.uuid4())
    
    ds.update_from_file(nebula.Target(vcf_uuid), args.vcf_input, create=True)
    ds.put(vcf_uuid, {'tumor_name' : args.tumor_name, 'type' : 'testing_input', 'file_type' : 'vcf'})

    ds.update_from_file(nebula.Target(cna_uuid), args.cna_input, create=True)
    ds.put(cna_uuid, {'tumor_name' : args.tumor_name, 'type' : 'testing_input', 'file_type' : 'cna'})

def command_clean(args):
    ds = nebula.docstore.FileDocStore(args.agro)
    error_count = 0
    for id, entry in ds.filter(state='error'):
        if entry.get('state', '') == 'error':
            #print "Delete", id
            ds.delete(nebula.Target(id))
            error_count += 1
    print "Error count", error_count

def command_list(args):
    ds = nebula.docstore.FileDocStore(args.agro)
    #ds = nebula.docstore.AgroDocStore(args.agro, "workdir")

    if args.type == "tumor":
        for t, meta in ds.filter(type="testing_input"):
            print meta['tumor_name'], meta['file_type'], t

    if args.type == "result":
        for t, meta in ds.filter():
            if 'tags' in meta and len(meta['tags']):
                print t, meta.get("tags", None), meta.get('state', None)
    
    if args.type == "error":
        for t, meta in ds.filter(state="error"):
            print t, meta['tags']
            print meta['job']['stdout']
            print meta['job']['stderr']


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--agro", default="localhost:9713")
    subparsers = parser.add_subparsers(title="subcommand")
    
    parser_run = subparsers.add_parser('run')
    parser_run.add_argument("tumor_name")
    parser_run.add_argument("entry_name")
    parser_run.add_argument("entry_dir")
    parser_run.set_defaults(func=command_run)

    parser_rename = subparsers.add_parser('docker-rename')
    parser_rename.add_argument("entry")
    parser_rename.set_defaults(func=command_rename)
    
    parser_loadinputs = subparsers.add_parser('load-input')
    parser_loadinputs.add_argument("tumor_name")
    parser_loadinputs.add_argument("vcf_input")
    parser_loadinputs.add_argument("cna_input")
    parser_loadinputs.set_defaults(func=command_loadinputs)

    parser_list = subparsers.add_parser("list")
    parser_list.add_argument("type", choices=['tumor', 'result', 'error'])
    parser_list.set_defaults(func=command_list)

    parser_clean = subparsers.add_parser("clean")
    parser_clean.set_defaults(func=command_clean)

    parser_extract = subparsers.add_parser("extract")
    parser_extract.add_argument("--out", default="output")
    parser_extract.set_defaults(func=command_extract)

    args = parser.parse_args()
    args.func(args)
