const fs = require("fs");
const nunjucks = require("nunjucks");

const config = {
    mock: false,
}

var list = [
    { src: "contracts/Params.template", dst: "contracts/Params.sol" },
];

for (let i = 0; i < list.length; i++) {
    const templateStr = fs.readFileSync(list[i].src).toString();
    const contractStr = nunjucks.renderString(templateStr, config);
    fs.writeFileSync(list[i].dst, contractStr)
}

console.log("generate system contracts success")