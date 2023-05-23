// conventional-changelog-action requires a JS pre-commit wrapper, but I didn't want to rewrite the shell tool...
exports.preCommit = (props) => {
  const version = props.version;
  const { exec } = require("child_process");

  exec(`bin/update-version ${version}`, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error: ${error.message}`);
      return;
    }

    if (stderr) {
      console.error(`stderr: ${stderr}`);
      return;
    }

    console.log(`stdout: ${stdout}`);
  });
};
