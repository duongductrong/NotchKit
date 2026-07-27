const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');

let newVersion = process.argv[2];

if (!newVersion) {
  const changelogPath = path.join(rootDir, 'CHANGELOG.md');
  if (fs.existsSync(changelogPath)) {
    const content = fs.readFileSync(changelogPath, 'utf8');
    const match = content.match(/## \[([0-9]+\.[0-9]+\.[0-9]+)\]/);
    if (match) {
      newVersion = match[1];
    }
  }
}

if (!newVersion) {
  console.error('Error: Version number not provided and could not be parsed from CHANGELOG.md');
  process.exit(1);
}

newVersion = newVersion.replace(/^v/, '');
console.log(`Updating hardcoded version numbers to: ${newVersion}`);

const filesToUpdate = [
  {
    path: 'README.md',
    replacements: [
      {
        pattern: /\.package\(url:\s*"https:\/\/github\.com\/duongductrong\/NotchKit\.git",\s*from:\s*"[^"]+"\)/g,
        replacement: `.package(url: "https://github.com/duongductrong/NotchKit.git", from: "${newVersion}")`
      }
    ]
  },
  {
    path: 'docs/getting-started.md',
    replacements: [
      {
        pattern: /\.package\(url:\s*"https:\/\/github\.com\/duongductrong\/NotchKit\.git",\s*from:\s*"[^"]+"\)/g,
        replacement: `.package(url: "https://github.com/duongductrong/NotchKit.git", from: "${newVersion}")`
      }
    ]
  },
  {
    path: 'llms.txt',
    replacements: [
      {
        pattern: /\.package\(url:\s*"https:\/\/github\.com\/duongductrong\/NotchKit\.git",\s*from:\s*"[^"]+"\)/g,
        replacement: `.package(url: "https://github.com/duongductrong/NotchKit.git", from: "${newVersion}")`
      }
    ]
  },
  {
    path: 'website/public/llms.txt',
    replacements: [
      {
        pattern: /\.package\(url:\s*"https:\/\/github\.com\/duongductrong\/NotchKit\.git",\s*from:\s*"[^"]+"\)/g,
        replacement: `.package(url: "https://github.com/duongductrong/NotchKit.git", from: "${newVersion}")`
      }
    ]
  },
  {
    path: 'website/src/routes/index.tsx',
    replacements: [
      {
        pattern: /v\d+\.\d+\.\d+/g,
        replacement: `v${newVersion}`
      },
      {
        pattern: /\.package\(url:\s*"https:\/\/github\.com\/duongductrong\/NotchKit\.git",\s*from:\s*"[^"]+"\)/g,
        replacement: `.package(url: "https://github.com/duongductrong/NotchKit.git", from: "${newVersion}")`
      }
    ]
  }
];

filesToUpdate.forEach(({ path: relativePath, replacements }) => {
  const filePath = path.join(rootDir, relativePath);
  if (!fs.existsSync(filePath)) {
    console.warn(`File not found: ${relativePath}`);
    return;
  }

  let content = fs.readFileSync(filePath, 'utf8');
  let modified = false;

  replacements.forEach(({ pattern, replacement }) => {
    if (pattern.test(content)) {
      content = content.replace(pattern, replacement);
      modified = true;
    }
  });

  if (modified) {
    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`Updated version in: ${relativePath}`);
  } else {
    console.log(`No version pattern match found in: ${relativePath}`);
  }
});
