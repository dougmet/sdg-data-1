#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

echo "HELLO"

SOURCE_BRANCH="master"
TARGET_BRANCH="master"
SHA=`git rev-parse --verify --short HEAD`

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    exit 0
fi

# Keys
openssl aes-256-cbc -K $encrypted_cb972ee281f6_key -iv $encrypted_cb972ee281f6_iv -in scripts/deploy/keys.tar.enc -out scripts/deploy/keys.tar -d
tar xvf scripts/deploy/keys.tar -C scripts/deploy/
rm scripts/deploy/keys.tar

echo "TRAVIS_TAG = " $TRAVIS_TAG


# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)

chmod 600 ./scripts/deploy/deploy_key
chmod 600 ./scripts/deploy/deploy_key_ds
eval `ssh-agent -s`
ssh-add scripts/deploy/deploy_key
ssh-add scripts/deploy/deploy_key_ds

git clone $TARGET_REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
cd ..

# Use the API_VERSION variable to put in the right place
# unset or empty
if [ -z "$API_VERSION" ]; then
  OUTDIR="out"
else
  OUTDIR="out/$API_VERSION"
fi

# Overwrite contents with _site
mkdir -p $OUTDIR
rm -rf $OUTDIR/**/* || exit 0

echo "Copying to $OUTDIR"
cp -r _site/* $OUTDIR
cp README.md $OUTDIR

# Now let's go have some fun with the cloned repo
cd out
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"
# Be careful with that key!
echo "*deploy_key*" >> .gitignore
echo "*keys.tar" >> .gitignore
echo "scripts/" >> .gitignore

# If there are no changes to the compiled out (e.g. this is a README update) then just bail.
if git diff --quiet; then
    echo "No changes to the output on this push; exiting."
    exit 0
fi

# Commit the "changes", i.e. the new version.
# The delta will show diffs between new and old versions.
git add -A .
git reset .gitignore
git commit -m "Deploy ${SHA} from branch ${TRAVIS_BRANCH}"

# Now that we're all set up, we can push.
git push $TARGET_REPO $TARGET_BRANCH