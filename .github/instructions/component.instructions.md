# Component instructions (MDX shared components)

> Scope: Use when authoring docs/**.mdx that import shared components from src/components/SharedMarkdown/.

## Shared MDX components

- Shared markdown components live in src/components/SharedMarkdown/.
- Prefer these components for standard sections to keep labs consistent.
- Use .mdx (not .md) when you need to import components.

## Required sections and components

- Use <Prerequisites /> for the prerequisites section. It already renders an H2 heading.
- Use <Cleanup /> for cleanup steps when applicable.
- Use <ProvisionResourceGroup /> and <ProvisionResources /> for Azure setup when the lab provisions resources.

## Import pattern

Place imports at the top of the file:

```mdx
import Prerequisites from "../../src/components/SharedMarkdown/_prerequisites.mdx";
import ProvisionResourceGroup from "../../src/components/SharedMarkdown/_provision_resource_group.mdx";
import ProvisionResources from "../../src/components/SharedMarkdown/_provision_resources.mdx";
import Cleanup from "../../src/components/SharedMarkdown/_cleanup.mdx";
```

## Usage notes

- Do not duplicate headings that the component already renders.
- Keep component usage close to where the section appears in the lab flow.
- If you need additional tools, pass the tools prop to <Prerequisites /> with name and url.

## Example

```mdx
<Prerequisites
  tools={[
    { name: "Helm", url: "https://helm.sh/docs/intro/install/" },
    { name: "Kustomize", url: "https://kubectl.docs.kubernetes.io/installation/kustomize/" },
  ]}
/>

<ProvisionResourceGroup />
<ProvisionResources />
```
