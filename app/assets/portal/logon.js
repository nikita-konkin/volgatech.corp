((username, password) => {
  const form = document.querySelector('#logonForm');
  if (!form) return {started: false};
  const login = form.querySelector('#username');
  const secret = form.querySelector('#password');
  const privateComputer = form.querySelector('#rdoPrvt');
  const changePassword = form.querySelector('#chpwd');
  const submit = form.querySelector('#SubmitCreds');
  if (!login || !secret || !privateComputer || !changePassword || !submit) {
    return {started: false};
  }
  login.value = username;
  secret.value = password;
  privateComputer.checked = true;
  changePassword.checked = false;
  submit.click();
  return {started: true};
})
