#!/usr/bin/env python

import os
import shutil
import synapseclient
import argparse


EVALUATION_QUEUE_ID = 4487063


def clean_str(s):
    #return s.encode('utf-8').replace(u"\xe4", u"a").replace(u'\xf6', u"o").replace(u'\xe1', u"a")
    return s

def command_list(syn, args):
    evaluation = syn.getEvaluation(EVALUATION_QUEUE_ID)
    print '\n\nSubmissions for: %s %s' % (evaluation.id, evaluation.name.encode('utf-8'))
    print '-' * 60
    format_str = "%-8s %-8s %-30s %-10s %-10s %-30s %-30s %-20s %-20s"
    if args.tab:
        format_str = "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s"
    print format_str % (
        "EntryID",
        "Team ID",
        "Date",
        "Status",
        "ProjectID",
        "EntryName",
        "Email",
        "Name",
        "Organisation"
    )
    for submission, status in syn.getSubmissionBundles(evaluation):
        team = syn.getTeam(submission.teamId)
        user = syn.getUserProfile(submission.userId)
        s = syn.getSubmission(submission.id)
        print format_str % (
            submission.id,
            clean_str(team.name),
            submission.createdOn,
            status.status,
            s.entity.annotations['synapse_projectid'][0],
            clean_str(submission.name),
            "%s@synapse.org" % (user['userName']),
            clean_str("%s %s" % (user['firstName'], user['lastName'])),
            clean_str(user.get('company', ''))
        )
        #print submission.entity
        #print s.entity
        
def command_download(syn, args):
    if not os.path.exists(args.out):
        os.mkdir(args.out)
    for i in args.ids:

        print "entry", i
        entry_dir = os.path.join(args.out, i)
        if not os.path.exists(entry_dir):
            os.mkdir(entry_dir)
        sub = syn.getSubmission(i)
        for ents in ['image_entities', 'tool_entities', 'workflow_entity']:
            for ent_id in sub.entity.annotations[ents]:
                print "downloading", ent_id
                ent = syn.get(ent_id)
                print ent.path
                if not args.cache_only:
                    shutil.copy(ent.path, os.path.join(entry_dir, os.path.basename(ent.path)))

def command_missing(syn, args):
    missing = []
    evaluation = syn.getEvaluation(EVALUATION_QUEUE_ID)
    for submission, status in syn.getSubmissionBundles(evaluation):
        sub = syn.getSubmission(submission.id)
        for ents in ['image_entities', 'tool_entities', 'workflow_entity', 'data_entities']:
            for ent_id in sub.entity.annotations[ents]:
                try:
                    ent = syn.get(ent_id)
                except:
                    missing.append( (submission.id, ent_id) )
    for subid, ent in missing:
        print subid, ent

                    
def command_info(syn, args):
    sub = syn.getSubmission(args.id)
    print sub.entity

def command_delete(syn, args):
    sub = syn.getSubmission(args.id)
    print "Deleting"
    syn.delete(sub)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    subparsers = parser.add_subparsers(title="subcommand")
    
    parser_list = subparsers.add_parser('list', help="List submissions to an evaluation or list evaluations")
    parser_list.add_argument("-t", dest="tab", action="store_true", default=False)
    parser_list.set_defaults(func=command_list)

    parser_info = subparsers.add_parser('info', help="List submissions to an evaluation or list evaluations")
    parser_info.add_argument("id")
    parser_info.set_defaults(func=command_info)

    parser_delete = subparsers.add_parser('delete')
    parser_delete.add_argument("id")
    parser_delete.set_defaults(func=command_delete)


    parser_download = subparsers.add_parser('download', help="Download submissions to an evaluation or list evaluations")
    parser_download.add_argument("--cache-only", action="store_true", default=False)
    parser_download.add_argument("--out", default="entries")
    parser_download.add_argument("ids", nargs="+")
    parser_download.set_defaults(func=command_download)

    parser_missing = subparsers.add_parser('missing')
    parser_missing.set_defaults(func=command_missing)

    args = parser.parse_args()
    syn = synapseclient.Synapse()
    syn.login()
    args.func(syn, args)
