"""Create one draft dependency-review PR using a trusted GitHub Actions token."""
import base64
import json
import os
import urllib.error
import urllib.request
from pathlib import Path


def api(path, data=None, method=None):
    req = urllib.request.Request("https://api.github.com/"+path, data=json.dumps(data).encode() if data is not None else None,
        headers={"Authorization": "Bearer "+os.environ["GH_TOKEN"], "Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "AwemeEnhance-upstream-review"}, method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def main():
    repository = os.environ["GITHUB_REPOSITORY"]
    lock = json.loads(Path("dependencies.lock.json").read_text())
    pin = lock["theos"]
    head = api(f"repos/{pin['repository']}/commits/{pin['ref']}")["sha"]
    if head == pin["sha"]:
        print("Pinned Theos is unchanged."); return
    branch = "codex/deps-theos-" + head[:12]
    pulls = api(f"repos/{repository}/pulls?state=open&head={repository.split('/')[0]}:{branch}")
    if pulls:
        print("A dependency review PR already exists."); return
    repo = api(f"repos/{repository}"); base = repo["default_branch"]
    base_sha = api(f"repos/{repository}/git/ref/heads/{base}")["object"]["sha"]
    try:
        api(f"repos/{repository}/git/refs", {"ref":"refs/heads/"+branch,"sha":base_sha})
    except urllib.error.HTTPError as error:
        if error.code != 422: raise
        existing=api(f"repos/{repository}/git/ref/heads/{branch}")["object"]["sha"]
        if existing != base_sha: raise RuntimeError("existing review branch differs; human review required") from error
    file = api(f"repos/{repository}/contents/dependencies.lock.json?ref={base}")
    old = pin["sha"]; pin["sha"] = head
    api(f"repos/{repository}/contents/dependencies.lock.json", {"branch":branch,"sha":file["sha"],"message":"chore(deps): propose reviewed Theos update","content":base64.b64encode((json.dumps(lock,indent=2)+"\n").encode()).decode()}, "PUT")
    pr = api(f"repos/{repository}/pulls", {"base":base,"head":branch,"draft":True,"title":"chore(deps): review Theos "+head[:12],"body":f"Proposed build-tool update `{old}` → `{head}`.\n\nReview upstream source, submodules, licenses, advisories and compiled output. Run Build/Test/Security manually on this branch (GITHUB_TOKEN-created PRs may not trigger workflows). Device validation remains required. **Never auto-merge.**"})
    print("Draft review PR created: "+pr["html_url"])


if __name__ == "__main__":
    main()
