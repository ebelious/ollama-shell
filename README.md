# ollama-shell

Ollama Shell is a terminal centric interface for ollama. This interface makes managing llms with ollama such as pulling, deleting, and running ollama very simple.
This is written in bash script with some other files and has few dependenicies. 

Dependencies:
`bash(or equivilent like zsh) less fzf python3 html2text curl ollama`<br>

*Note: source OLLAMA_HOST in your .bashrc (if not using bash change the source in `ollama.sh` to where this can be sources from). `source` is at top of the file* <br>
put in the following in your `~/.bashrc`<br>

```export OLLAMA_HOST=http://YOURHOST:11434```a

![menu](https://github.com/ebelious/ollama-shell/blob/main/2026-02-15_23-02-1771215602.jpg)


## Install
`git clone https://github.com/ebelious/ollama-shell.git`

## Usage
run like any other bash script `./SCRIPT`

Navigation is simple. entering the letters or numbers asociated with the options. You dont need to be in the main menu to navigate to other menus <br>
*except updating ollama, and setting the server, refresing model list*
