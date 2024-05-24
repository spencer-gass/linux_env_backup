cp -f settings.json ~/.config/Code/User/settings.json
cp -f keybindings.json ~/.config/Code/User/keybindings.json
cp -rf snippets ~/.config/Code/User/snippets
cat vscode_extensions.txt | xargs -L 1 code --install-extension



