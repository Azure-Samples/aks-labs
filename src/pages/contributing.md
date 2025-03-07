# Contributing to AKS Labs

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

 - [Code of Conduct](#coc)
 - [Issues and Bugs](#issue)
 - [Feature Requests](#feature)
 - [Submission Guidelines](#submit)

## Code of Conduct {#coc}

Help us keep this project open and inclusive. Please read and follow our [Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

## Found an Issue? {#issue}

If you find a bug in the source code or a mistake in the documentation, you can help us by
[submitting an issue](#submit-issue) to the GitHub Repository. Even better, you can
[submit a Pull Request](#submit-pr) with a fix.

## Want a Feature? {#feature}

You can *request* a new feature by [submitting an issue](#submit-issue) to the GitHub
Repository. If you would like to *implement* a new feature, *please submit an issue with
a proposal for your work first, to be sure that we can use it*.

- **Small Features** can be crafted and directly [submitted as a Pull Request](#submit-pr).

## Submission Guidelines {#submit}

When putting together your workshop, you need to consider how long it will take to complete. Ideally, we want to keep the workshops *under 2 hours*. If you think your workshop will take longer than that, please consider breaking it up into multiple workshops.

Another point to consider before making a submission is whether what you are submitting is already covered in the existing Microsoft Learn content. We are not trying to duplicate the content that is already available on Microsoft Learn, so please check there first. If you find that your workshop is similar to existing content, please consider submitting a PR to update the existing content instead of creating a new workshop.

You might also want to consider exploring scenarios other than AKS features because the AKS team is already doing a great job of covering those. For example, you could explore how to use AKS with other Azure services like Azure Functions, Azure Logic Apps, or Azure DevOps. You could also explore how to use AKS with other open source tools like Helm, Istio, or ArgoCD. The possibilities are endless!

Finally, consider the scenario you are trying to cover. We want to make sure that the workshops are accessible to anyone who wants to learn. For example, while we are happy to have workshops that cover AI and ML, if your lab requires the use of more advanced tools like Azure OpenAI, please consider whether the audience will be able to complete the workshop without having to sign up for a paid service. We want to make sure that the workshops are accessible to everyone, so please keep this in mind when creating your content. If you are unsure whether your workshop is relevant or accessible, please reach out to us and we can help you determine whether it is a good fit for the project.

### Style Guide {#styleguide}

Our style guide is pretty simple. If you haven't guessed by now, our site is built on [Docusaurus](https://docusaurus.io/). For the most part, we use the default Docusaurus theme, so you can refer to their [style guide](https://docusaurus.io/docs/markdown-features) for more information. Check out the other workshop docs in the `docs` folder for examples of how to format your content. Our format is pretty simple:

---

```text
# Title

Title of your page

## Objective

This is a short description of what the reader will learn in this workshop.

## Prerequisites

This is a list of what the reader needs to know and/or installed in their environment  before starting the workshop.

## Workshop Content

This is the content of the workshop. It can be a mix of text, code snippets, and images. Use the Docusaurus markdown features to format your content.
```

---

Finally, at the top of the page, you will need to add some metadata so that Docusaurus can build the page correctly. Here is an example:

```text
---
title: Your Workshop Title
sidebar_label: The label you want to display in the sidebar (usually the title)
sidebar_position: 1 (this dictates the order of the pages in the sidebar)
---
```

### Submitting an Issue {#submit-issue}

Before you submit an issue, search the archive, maybe your question was already answered.

If your issue appears to be a bug, and hasn't been reported, open a new issue.
Help us to maximize the effort we can spend fixing issues and adding new
features, by not reporting duplicate issues.  Providing the following information will increase the
chances of your issue being dealt with quickly:

- **Overview of the Issue** - if an error is being thrown a non-minified stack trace helps
- **Version** - what version is affected (e.g. 0.1.2)
- **Motivation for or Use Case** - explain what are you trying to do and why the current behavior is a bug for you
- **Browsers and Operating System** - is this a problem with all browsers?
- **Reproduce the Error** - provide a live example or a unambiguous set of steps
- **Related Issues** - has a similar issue been reported before?
- **Suggest a Fix** - if you can't fix the bug yourself, perhaps you can point to what might be
  causing the problem (line of code or commit)

You can file new issues by providing the above information at the corresponding repository's issues link: [https://github.com/Azure-Samples/aks-labs/issues/new](https://github.com/Azure-Samples/aks-labs/issues/new).

### Submitting a Pull Request (PR) {#submit-pr}

Before you submit your Pull Request (PR) consider the following guidelines:

- Search the repository [https://github.com/Azure-Samples/aks-labs/pulls](https://github.com/Azure-Samples/aks-labs/pulls) for an open or closed PR
  that relates to your submission. You don't want to duplicate effort.

- Fork the repository and make your changes in your local fork.

- Commit your changes using a descriptive commit message

- Push your fork to GitHub:

- In GitHub, create a pull request

- If we suggest changes then:

  - Make the required updates.
  - Rebase your fork and force push to your GitHub repository (this will update your Pull Request):

    ```shell
    git rebase master -i
    git push -f
    ```

That's it! Thank you for your contribution!
