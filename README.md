# kitodo-presentation-docker
Docker configuration for kitodo-presentation
todo

# Kitodo.Presentation
todo

## Kitodo. Digital Library Modules

[Kitodo](https://github.com/kitodo) is an open source software suite intended to support mass digitization projects for cultural heritage institutions. Kitodo is widely used and cooperatively maintained by major German libraries and digitization service providers. The software implements international standards such as METS, MODS, ALTO, and other formats maintained by the Library of Congress. Kitodo consists of several independent modules serving different purposes such as controlling the digitization workflow, enriching descriptive and structural metadata, and presenting the results to the public in a modern and convenient way.

For more information, visit the [Kitodo homepage](https://www.kitodo.org). You can also follow Kitodo News on [Twitter](https://twitter.com/kitodo_org).

## Docker instructions
### Build image:
'docker build -t kitodo/presentation:3.3 .'

### Run image:
'docker run -p 80:80 kitodo/presentation:3.3'

### Tmp workaround: start mariadb: 
(gets obsolete when docker-compose works)
Get container hash:  'docker ps'
start mariadb in container:  'docker exec <container hash> service mariadb start'

### Ready:
http://localhost/typo3/


## Code and User Feedback
todo