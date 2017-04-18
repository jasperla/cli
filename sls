#!/usr/bin/env python
import os
import sys
import getopt
import requests
import yaml
import zipfile
import shutil
import subprocess


def usage():
    print 'Usage: sls [-i|--init] [-l|--list] [-u|--update <sls>]'


def process_config(config):
    try:
        config = yaml.load(config)
    except ValueError as err:
        print 'ERROR: YAML decode error, please use valid YAML'
        sys.exit(2)

    if 'source' not in config:
        print 'ERROR: Key source not found in config'
        sys.exit(2)

    if 'sls' not in config:
        print 'ERROR: Key sls not found in config'
        sys.exit(2)

    states = {}
    for state in config['sls']:
        if type(state) is dict:
            key = list(state)[0]
            value = state[key]
        else:
            key = state
            value = ""
        states[key] = value

    return config['source'], states


def init_sls():
    top_sls = open('top.sls', 'w')
    top_sls.write('base:\n')
    top_sls.write('  \'*\':\n')
    top_sls.write('    - saltstates\n')
    top_sls.close()


def local_sls():
    sls = {}
    dirs = [d for d in os.listdir('.') if os.path.isdir(d) and d != '.git']
    for d in dirs:
        try:
            with open("{}/VERSION".format(d,), 'r') as f:
                version = f.read()
            f.closed
        except IOError as err:
            pass

        try:
            version = yaml.load(version)
        except ValueError as err:
            print 'ERROR: YAML decode error, please use valid YAML'
            sys.exit(2)
        sls[version['name']] = version['version']
    return sls


def rm_sls(state):
    try:
        shutil.rmtree(state)
        print "removing sls: {}".format(state,)
    except OSError as err:
        pass
    return


def list_sls():
    sls = local_sls()
    for state in sls:
        print("{}: {}".format(state, sls[state]))


def update_sls(config, state):
    source, sls = process_config(config)

    rm_sls(state)
    setup_sls(config)
    return


def download_sls(state, url):
    local_filename = '/tmp/sls.zip'
    r = requests.get(url, stream=True)
    with open(local_filename, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024): 
            if chunk: # filter out keep-alive new chunks
                f.write(chunk)

    zip_ref = zipfile.ZipFile(local_filename, 'r')
    extract_dir = zip_ref.namelist()[0]
    zip_ref.extractall('.')
    zip_ref.close()
    os.rename(extract_dir, state)
    os.remove(local_filename)


def git_clone_sls(state, url):
    git_clone = subprocess.check_output(['git', 'clone', url, state])


def setup_sls(config):
    installed_sls = local_sls()
    source, states = process_config(config)

    # Get sls
    remote_sls = {}
    git_sls = {}
    for state in states:
        if 'git:' in states[state]:
            git_sls[state] = {}
            git_sls[state]['url'] = states[state][4:]
            continue
        req = requests.post("{}/install".format(source,), data = {'sls':state, 'version':states[state]}).json()
        if 'error' in req:
            print "ERROR: {}: {}".format(state, req['error'])
            sys.exit(2)
        for remote_state in req.keys():
            remote_sls[remote_state] = {}
            remote_sls[remote_state]['version'] = req[remote_state]['version']
            remote_sls[remote_state]['url'] = req[remote_state]['url']

    # Install sls
    for state in remote_sls:
        if state in installed_sls:
            continue
        download_sls(state, remote_sls[state]['url'])
    for state in git_sls:
        if state in installed_sls:
            continue
        git_clone_sls(state, git_sls[state]['url'])

    # Remove sls
    installed_sls = local_sls()
    for installed_state in installed_sls:
        if installed_state not in remote_sls and installed_state not in git_sls:
            rm_sls(installed_state)
    return


def main():
    try:
        with open('.sls', 'r') as f:
            config = f.read()
        f.closed
    except IOError as err:
        print 'ERROR: Failed reading .sls, make sure it exists, is readable and in json format'
        sys.exit(2)

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'hilu:', ['help', 'install', 'list', 'update='])
    except getopt.GetoptError as err:
        print str(err)
        usage()
        sys.exit(2)

    for o, a in opts:
        if o in ('-h', '--help'):
            usage()
            sys.exit()
        elif o in ('-i', '--init'):
            init_sls()
            sys.exit()
        elif o in ('-l', '--list'):
            list_sls()
            sys.exit()
        elif o in ('-u', '--update'):
            update_sls(config, a)
            sys.exit()
    setup_sls(config)


if __name__ == '__main__':
    main()
