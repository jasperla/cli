## Install sls
The command line tool sls will help you with installing salt states 
from saltstates.org or any git repository.

## Using sls
On your salt master go to the directory containing your salt states,
usually /srv/salt/states.

Create a .sls file in the salt states directory containing:
```
source: 'https://saltstates.org'
sls:
  - <state>
  - <state>: '<version>'
  - <state>: 'git:<git url>'
```

Now just run sls and you are done:
```
$ sls
```
