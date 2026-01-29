# AKS Labs - GitHub Copilot Instructions

> Scope: Repository-wide standards and writing guidance for hands-on labs, workshops, and teaching content.
> Module-specific guidance may appear in subfolders (for example, README files under docs/).
> File-specific guidance lives in .github/instructions/*.instructions.md.

---

## Part 1: Repository standards

### Repository overview

This repo hosts a Docusaurus site with hands-on AKS labs and workshop content. Content lives in docs/, blog/, and pages, with supporting assets under docs/\*\*/assets/.

### Primary content types

- Labs and workshops: docs/**.md or docs/**.mdx
- Guides and reference docs: docs/**.md or docs/**.mdx
- Blog posts: blog/\*\*
- React components: src/components/\*\*

### Content principles (workshops and labs)

- Goal-first: Start with the lab outcome and what the learner will build.
- Prerequisites: List required tools, versions, subscriptions, and access.
- Time estimates: Include an estimated duration per section.
- Step clarity: Use numbered steps with imperative verbs.
- Expected results: Include validation steps and sample outputs.
- Recap learning: End each lab with a short summary that restates what the learner achieved and learned.
- Troubleshooting: Add a short troubleshooting section with common errors.
- Safety: Call out cost, cleanup steps, and permissions.

### Docusaurus conventions

- Front matter required for new docs (id, title, sidebar_position when needed).
- Use sentence-style headings.
- Keep sections short and scannable.
- Prefer MDX only when components are required.

### File naming

| Type            | Convention                             | Example                      |
| :-------------- | :------------------------------------- | :--------------------------- |
| Markdown        | kebab-case.md                          | getting-started.md           |
| MDX             | kebab-case.mdx                         | aks-automatic.mdx            |
| React component | PascalCase.tsx                         | LandingPage.tsx              |
| TS utility      | camelCase.ts                           | analytics.ts                 |
| CSS             | kebab-case.css or Component.module.css | custom.css, Index.module.css |
| YAML            | kebab-case.yaml or .yml                | deployment.yaml              |
| Shell scripts   | kebab-case.sh                          | setup-cluster.sh             |

### Code style

- Markdown: CommonMark; keep lines readable and wrap long paragraphs.
- YAML: 2 spaces, no tabs.
- Shell: bash with set -euo pipefail; add prerequisite checks.
- TypeScript: ESLint defaults; functional React components with hooks.
- Code samples: Use fenced code blocks with triple backticks and a language identifier, such as bash, python, or typescript.
- Inline code: Use single backticks only for code terms embedded in normal sentences (for example, `kubectl`).

### Links and images

- Use descriptive link text (avoid “click here”).
- Prefer relative links within the repo.
- Provide alt text for all images.
- Store images under the nearest docs/\*\*/assets/ folder.

### Kubernetes and Azure examples

- Never use :latest images.
- Always include resource requests and limits in manifests.
- Include labels and namespaces where relevant.
- Avoid embedding secrets; use placeholders and Key Vault references.

### Security and privacy

- Never commit secrets, tokens, or credentials.
- Avoid customer-specific data or personal email addresses.
- Use generic sample values (example-resource-group, example-cluster).

### Build and development

This is a Docusaurus site. Typical commands:

- npm install
- npm start
- npm run build
- npm run typecheck

### Git workflow

- Use Conventional Commits for messages and PR titles.
- Keep PRs focused and include validation notes for doc changes.

### Azure tooling rule

- @azure Rule - Use Azure Best Practices: When generating code for Azure, running terminal commands for Azure, or performing operations related to Azure, invoke your get_azure_best_practices tool if available.
- Agents may call MCP clients when needed and when allowed by repo rules.

---

## Part 2: Lab writing guide (summary)

### Voice and tone

- Crisp, clear, and friendly.
- Use second person and imperative verbs.
- Prefer input-neutral verbs (select, enter, choose).

### Lab structure

1. Overview
2. Objectives
3. Prerequisites
4. Architecture or concept brief
5. Steps
6. Validation
7. Summary (recap what the learner learned)
8. Cleanup
9. Troubleshooting

### Steps formatting

- Use numbered lists for procedures.
- Keep steps short and focused.
- Use bold for UI elements.
- Provide copy-pasteable commands.

### Troubleshooting guidance

- Include error message snippets when possible.
- Provide the most likely fix first.
- Link to official docs for deeper dives.

### Accessibility

- Provide alt text for images.
- Avoid directional-only guidance (for example, “click the button on the right”).
- Use descriptive link text.

---

## Part 3: Terminology reminders

- Azure Kubernetes Service (AKS) on first mention, then AKS.
- kubectl and kubeconfig are lowercase.
- Cluster, node, pod, and namespace are lowercase as common nouns.
- Deployment, Service, and Ingress are capitalized when referring to resource types.

---

## Part 4: When editing existing content

- Preserve the current structure unless there is a clear improvement.
- Keep front matter consistent with existing patterns.
- Do not reorder sidebars or categories unless asked.
- Avoid sweeping refactors; make minimal, targeted changes.

---

## Part 5: Microsoft Style Guide

### Voice and Tone

The Microsoft voice is **simple and human**. Our voice hinges on crisp simplicity—bigger ideas and fewer words.

#### Three Voice Principles

- **Warm and relaxed:** Natural, less formal, grounded in everyday conversation. Occasionally fun.
- **Crisp and clear:** To the point. Write for scanning first, reading second. Make it simple above all.
- **Ready to lend a hand:** Show customers we're on their side. Anticipate their needs.

#### Key Style Tips

- **Get to the point fast:** Start with the key takeaway. Front-load keywords for scanning.
- **Talk like a person:** Use optimistic, conversational language. Use contractions (_it's_, _you're_, _we're_, _let's_).
- **Simpler is better:** Short sentences and fragments are easier to scan. Prune every excess word.
- **Revise weak writing:** Start with verbs. Edit out _you can_ and _there is/are/were_.

#### Examples

| Replace this                                                                                                                                    | With this                                                                                                         |
| :---------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------- |
| If you're ready to purchase Office 365 for your organization, contact your Microsoft account representative.                                    | Ready to buy? Contact us.                                                                                         |
| Invalid ID                                                                                                                                      | You need an ID that looks like this: someone@example.com                                                          |
| Templates provide a starting point for creating new documents. A template can include the styles, formats, and page layouts you use frequently. | Save time by creating a document template that includes the styles, formats, and page layouts you use most often. |
| You can access Office apps across your devices, and you get online file storage and sharing.                                                    | Store files online, access them from all your devices, and share them with coworkers.                             |

### Cloud Computing Terms

**Azure**: Capitalize.
**back end, back-end**: Two words as a noun. Hyphenate as an adjective (_back-end services_).
**bandwidth**: One word.
**cloud, the cloud**: Don't capitalize unless referring to _Microsoft Cloud_ or a product name. Use mostly as an adjective (_cloud services_). Avoid using _the cloud_ as a noun—talk about _cloud computing_ or _cloud services_ instead.
**cloud computing**: Lowercase. Two words. Use instead of _the cloud_.
**cloud native, cloud-native**: Lowercase. Hyphenate as an adjective (_cloud-native app_). Don't use _born in the cloud_.
**content delivery network**: Lowercase. Always spell out; don't use _CDN_.
**cross-platform**: Hyphenate.
**data center**: Two words.
**edge, edge computing**: Lowercase. Use _at the edge_, not _on the edge_.
**front-end, front end**: Hyphenate as an adjective (_front-end development_). Two words as a noun.
**hybrid cloud**: Define on first mention for non-technical audiences.
**infrastructure as a service (IaaS)**: Technical audiences only. Don't capitalize as _IAAS_. Don't hyphenate as a modifier.
**the Microsoft Cloud**: Capitalize. Refers to the entire Microsoft cloud platform (Azure, Dynamics 365, Microsoft 365, etc.). Include _the_ before it.
**multicloud**: One word, no hyphen. Use for technical audiences.
**multitenant, multitenancy**: One word, no hyphen.
**on-premises, off-premises**: Hyphenate in all positions. _Premises_ is plural—never use _on-premise_.
**open source**: Noun. Hyphenate as an adjective (_open-source software_).
**platform as a service (PaaS)**: Technical audiences only. Don't capitalize as _PAAS_.
**server-side**: Hyphenate as an adjective.
**serverless**: One word, no hyphen.
**software as a service (SaaS)**: Don't capitalize as _SAAS_. Don't hyphenate as a modifier.
**third-party**: Hyphenate as an adjective. Two words as a noun (_third party_).

### Kubernetes Terms

#### Core Concepts

**cluster**: Lowercase. A set of nodes that run containerized applications managed by Kubernetes.
**node**: Lowercase. A worker machine in Kubernetes (physical or virtual).
**pod**: Lowercase. The smallest deployable unit in Kubernetes, containing one or more containers.
**container**: Lowercase. A lightweight, standalone executable package that includes everything needed to run an application.
**namespace**: Lowercase. A way to divide cluster resources between multiple users or projects.
**workload**: Lowercase. An application running on Kubernetes.
**object**: Lowercase. An entity in the Kubernetes system representing cluster state (e.g., Pod, Service, Deployment).
**spec**: Lowercase. Defines how each object should be configured and its desired state.
**status**: Lowercase. The current state of a Kubernetes object, managed by the system.
**name**: Lowercase. A client-provided string that uniquely identifies an object within a namespace.
**UID**: Uppercase. A Kubernetes-generated string to uniquely identify objects across the cluster.
**API group**: Lowercase. A set of related paths in the Kubernetes API.
**API server, kube-apiserver**: Lowercase. The control plane component that exposes the Kubernetes API.

#### Workload Resources

**Deployment**: Capitalize when referring to the Kubernetes resource type. Manages a replicated application.
**ReplicaSet**: One word, capitalize. Ensures a specified number of pod replicas are running.
**StatefulSet**: One word, capitalize. Manages stateful applications with stable network identifiers.
**DaemonSet**: One word, capitalize. Ensures all (or some) nodes run a copy of a pod.
**Job**: Capitalize when referring to the Kubernetes resource. Creates one or more pods and ensures successful completion.
**CronJob**: One word, capitalize. Creates Jobs on a repeating schedule.
**replica**: Lowercase. A copy or duplicate of a pod for high availability and scalability.
**init container**: Lowercase. One or more initialization containers that must run to completion before app containers start.
**sidecar container**: Lowercase. One or more containers typically started before app containers to provide supporting features.
**ephemeral container**: Lowercase. A temporary container type for debugging running pods.

#### Service and Networking

**Service**: Capitalize when referring to the Kubernetes resource type. An abstract way to expose an application running on pods.
**Ingress**: Capitalize. Manages external access to services, typically HTTP.
**Ingress controller**: _Ingress_ capitalized, _controller_ lowercase. A component that implements Ingress rules.
**load balancer**: Lowercase. Distributes network traffic across multiple servers.
**ClusterIP**: One word, capitalize. Default service type, exposes service on internal cluster IP.
**NodePort**: One word, capitalize. Exposes service on each node's IP at a static port.
**LoadBalancer**: One word, capitalize when referring to the Kubernetes service type.
**NetworkPolicy**: One word, capitalize. Specifies how pods are allowed to communicate with each other and other network endpoints.
**EndpointSlice**: One word, capitalize. A scalable way to track network endpoints for a Service.
**Gateway API**: Capitalize both words. A family of API kinds for modeling service networking.
**DNS**: Uppercase. Cluster-wide DNS resolution for services and pods.
**CNI (Container Network Interface)**: Spell out on first mention. The standard for network plugins in Kubernetes.

#### Configuration and Storage

**ConfigMap**: One word, capitalize. Stores non-confidential configuration data as key-value pairs.
**Secret**: Capitalize when referring to the Kubernetes resource. Stores sensitive information like passwords and tokens.
**PersistentVolume (PV)**: One word, capitalize. A piece of storage in the cluster provisioned by an administrator.
**PersistentVolumeClaim (PVC)**: One word, capitalize. A request for storage by a user.
**StorageClass**: One word, capitalize. Describes the "classes" of storage available.
**Volume**: Capitalize when referring to the Kubernetes resource. A directory containing data accessible to containers in a pod.
**CSI (Container Storage Interface)**: Spell out on first mention. The standard for storage plugins in Kubernetes.
**emptyDir**: One word, camelCase. A temporary volume that shares a pod's lifetime.
**hostPath**: One word, camelCase. Mounts a file or directory from the host node's filesystem.
**container environment variables**: Lowercase. Name-value pairs providing configuration to containers.

#### Azure Kubernetes Service (AKS)

**Azure Kubernetes Service (AKS)**: Spell out on first mention, then use _AKS_. Don't use _Azure Container Service_.
**node pool**: Two words, lowercase. A group of nodes with the same configuration in AKS.
**system node pool**: Lowercase. Hosts critical system pods.
**user node pool**: Lowercase. Hosts application workloads.
**virtual nodes**: Lowercase. Enable scaling with Azure Container Instances.
**managed identity**: Lowercase. Azure-managed credentials for AKS clusters.
**Azure CNI**: Capitalize _Azure_, uppercase _CNI_. Azure's container network interface implementation.
**kubenet**: Lowercase. Basic network plugin that creates a bridge and allocates IP addresses.
**KEDA (Kubernetes Event-driven Autoscaling)**: Spell out on first mention. Event-driven pod autoscaling for AKS.
**cluster autoscaler**: Lowercase. Automatically adjusts node pool size based on demand.
**Horizontal Pod Autoscaler (HPA)**: Capitalize resource name. Scales pod replicas based on metrics.
**Vertical Pod Autoscaler (VPA)**: Capitalize resource name. Adjusts resource requests and limits for containers.
**Azure Policy for AKS**: Capitalize _Azure Policy_. Enforces governance policies on AKS clusters.
**Azure Monitor for containers**: Capitalize _Azure Monitor_. Monitoring solution for AKS clusters.
**Microsoft Defender for Containers**: Capitalize. Security solution for containerized environments.

#### Tools and Commands

**kubectl**: Lowercase. The Kubernetes command-line tool. Pronounced "kube control" or "kube C-T-L".
**Helm**: Capitalize. A package manager for Kubernetes.
**Helm chart**: _Helm_ capitalized, _chart_ lowercase. A collection of files describing Kubernetes resources.
**kubeconfig**: Lowercase. Configuration file for kubectl to access clusters.
**Kustomize**: Capitalize. A tool for customizing Kubernetes configurations.
**k9s**: Lowercase. A terminal-based UI for managing Kubernetes clusters.
**Azure CLI, az**: Capitalize _Azure CLI_. Lowercase _az_ command. Azure command-line interface for AKS management.

#### Other Kubernetes Terms

**control plane**: Two words, lowercase. The container orchestration layer that manages the cluster.
**kubelet**: Lowercase. An agent that runs on each node ensuring containers are running in a pod.
**kube-proxy**: Lowercase, hyphenated. Network proxy that runs on each node.
**etcd**: Lowercase. Consistent and highly available key-value store for cluster data.
**container runtime**: Lowercase. Software responsible for running containers (e.g., containerd).
**manifest**: Lowercase. A YAML or JSON file that defines Kubernetes resources.
**label**: Lowercase. Key-value pairs attached to objects for identification.
**annotation**: Lowercase. Key-value pairs for attaching non-identifying metadata.
**selector**: Lowercase. Used to filter resources based on labels.
**rolling update**: Lowercase. A deployment strategy that gradually replaces pod instances.
**liveness probe, readiness probe, startup probe**: Lowercase. Diagnostic checks that kubelet performs on containers.
**kube-controller-manager**: Lowercase, hyphenated. Control plane component that runs controller processes.
**kube-scheduler**: Lowercase, hyphenated. Control plane component that assigns pods to nodes.
**cloud-controller-manager**: Lowercase, hyphenated. Control plane component that integrates with cloud providers.
**controller**: Lowercase. A control loop that watches cluster state and makes changes to move toward desired state.
**CustomResourceDefinition (CRD)**: One word, capitalize. Defines a new custom API to extend Kubernetes.
**custom resource**: Lowercase. An extension of the Kubernetes API defined by a CRD.
**Operator**: Capitalize. A method of packaging, deploying, and managing a Kubernetes application using custom resources.
**ServiceAccount**: One word, capitalize. Provides an identity for processes running in a pod.
**RBAC (Role-Based Access Control)**: Spell out on first mention. Manages authorization through the Kubernetes API.
**Role, ClusterRole**: Capitalize. Define permissions within a namespace (Role) or cluster-wide (ClusterRole).
**RoleBinding, ClusterRoleBinding**: One word, capitalize. Grant permissions defined in a Role or ClusterRole.
**taint**: Lowercase. Prevents pods from being scheduled on a node unless they tolerate the taint.
**toleration**: Lowercase. Allows a pod to be scheduled on a node with a matching taint.
**affinity**: Lowercase. Rules that give hints to the scheduler about where to place pods.
**node affinity**: Lowercase. Constrains which nodes a pod can be scheduled on based on node labels.
**pod affinity, pod anti-affinity**: Lowercase. Constrains pod placement based on labels of other pods.
**PodDisruptionBudget (PDB)**: One word, capitalize. Limits the number of pods that can be down simultaneously.
**ResourceQuota**: One word, capitalize. Constrains aggregate resource consumption per namespace.
**LimitRange**: One word, capitalize. Constrains resource consumption per container or pod in a namespace.
**QoS class (Quality of Service class)**: Lowercase _class_. Classifies pods for scheduling and eviction decisions (Guaranteed, Burstable, BestEffort).
**finalizer**: Lowercase. A namespaced key that delays deletion until specific conditions are met.
**garbage collection**: Lowercase. Mechanisms Kubernetes uses to clean up cluster resources.
**drain**: Lowercase. The process of safely evicting pods from a node for maintenance.
**cordon**: Lowercase. Marks a node as unschedulable without evicting existing pods.
**eviction**: Lowercase. The process of terminating pods on a node.
**preemption**: Lowercase. Terminating lower-priority pods to make room for higher-priority pods.
**priority class**: Lowercase. Defines the priority of a pod relative to other pods.
**static pod**: Lowercase. A pod managed directly by the kubelet on a specific node.
**mirror pod**: Lowercase. A pod object representing a static pod in the API server.
**event**: Lowercase. A Kubernetes object describing state changes or notable occurrences.
**feature gate**: Lowercase. A set of keys to control which Kubernetes features are enabled.
**containerd**: Lowercase. An industry-standard container runtime.
**CRI-O**: Uppercase CRI, uppercase O. A lightweight container runtime for Kubernetes.
**cgroup (control group)**: Lowercase. A Linux kernel feature for resource isolation and limits.
**Pod lifecycle**: _Pod_ capitalized. The sequence of states a pod passes through during its lifetime.
**image**: Lowercase. A stored instance of a container holding software needed to run an application.
**image pull policy**: Lowercase. Determines when the kubelet pulls a container image (Always, IfNotPresent, Never).

### Computer and Device Terms

#### Devices

**device, mobile device**: Use _device_ as a general term for all computers, phones, and devices. Use _mobile device_ only when calling out mobility.
**computer, PC**: Use _computer_ when talking about computing devices other than phones. _PC_ is OK when space is limited.
**phone, mobile phone, smartphone**: Use _phone_ most of the time. Use _smartphone_ only to distinguish from other phones. Don't use _cell phone_ or _cellular phone_.
**tablet, laptop**: Use only when talking about specific classes of computers.
**Mac**: Capitalize.
**touchscreen**: One word.

#### Hardware Actions

**turn on, turn off**: Use instead of _power on/off_, _switch on/off_, _enable/disable_ for features or settings.
**restart**: Use instead of _reboot_.
**set up, setup**: _Set up_ (two words) is a verb. _Setup_ is a noun or adjective.
**start up, startup**: _Start up_ is a verb. _Startup_ is a noun or adjective.
**install, uninstall**: Use for adding and removing hardware drivers and apps.
**connect, disconnect**: Use for relationships between devices or network connections.
**back up, backup**: _Back up_ is a verb. _Backup_ is a noun or adjective.
**download, upload**: Use as verbs. Avoid using _download_ as a noun to refer to the file itself (use _file_).
**sync**: Acceptable abbreviation for _synchronize_.

#### UI Elements

**button**: Do not use _button_ in instructions unless necessary for clarity (e.g., _Select Save_, not _Select the Save button_).
**checkbox**: One word.
**check mark**: Two words.
**combo box**: Two words.
**context menu**: Avoid. Use _shortcut menu_.
**desktop**: Use to refer to the working area of the screen. Do not use to refer to a computer (use _computer_ or _PC_).
**dialog**: Use _dialog_, not _dialog box_.
**drop-down**: Adjective. Use _drop-down list_ for the noun.
**menu bar**: Two words.
**pop-up**: Hyphenate as an adjective or noun.
**scroll bar**: Two words.
**status bar**: Two words.
**submenu**: One word.
**system tray**: Avoid. Use _notification area_.
**tab**: Use bold for tab names.
**taskbar**: One word.
**text box**: Two words.
**title bar**: Two words.
**toolbar**: One word.
**tooltip**: One word.
**wizard**: Lowercase unless part of a feature name.

#### Files and Folders

**browse**: Use _browse_ to refer to looking for files.
**file name**: Two words.
**folder**: Use _folder_, not _directory_, in Windows contexts.
**disk**: Use _disk_ for magnetic media (hard disk). Use _disc_ for optical media (CD, DVD).
**hard drive**: Use instead of _hard disk_.
**screenshot**: One word.

### Keys and Keyboard Shortcuts

#### Terminology

- **keyboard shortcut**: Use to describe a combination of keystrokes (e.g., _Ctrl+V_). Don't use _accelerator key_, _fast key_, _hot key_, _quick key_, or _speed key_.
- **select**: Use to describe pressing a key. Don't use _press_, _depress_, _hit_, or _strike_.

#### Key Names

Capitalize key names: _Enter_, _Shift_, _Esc_, _Tab_, _Spacebar_, _Backspace_, _Delete_, _Ctrl_, _Alt_, _Home_, _End_, _Page up_, _Page down_, _F1–F12_, _Windows logo key_.

#### Key Combinations

- Use the plus sign (+) with no spaces: _Ctrl+V_, _Alt+F4_, _Ctrl+Shift+Esc_.
- Spell out: _Plus sign_, _Minus sign_, _Hyphen_, _Period_, _Comma_ to avoid confusion.
- For arrow keys, use: _Left arrow key_, _Right arrow key_, _Up arrow key_, _Down arrow key_.

### Security Terms

**antimalware, antivirus, antispyware, antiphishing**: Use only as adjectives.
**attacker, malicious hacker, unauthorized user**: Use instead of _hacker_ in content for general audiences.
**authentication**: Lowercase.
**blocklist**: Use instead of _blacklist_.
**allowlist**: Use instead of _whitelist_.
**cybersecurity**: One word.
**firewall**: One word.
**malware, malicious software**: Use _malware_ to describe unwanted software (viruses, worms, trojans). Define on first mention if needed.
**sign in, sign out**: Use instead of _log on/off_, _log in/out_, _login/logout_.
**vulnerability**: Use modifiers to specify type (product vulnerability, administrative vulnerability, physical vulnerability).

### Web and Internet Terms

**blog**: Lowercase.
**browser**: Lowercase.
**e-book**: Hyphenate.
**e-commerce**: Hyphenate.
**email**: One word, no hyphen. Do not use _e-mail_.
**homepage**: One word.
**inbox**: One word.
**internet**: Lowercase.
**intranet**: Lowercase.
**offline**: One word.
**online**: One word.
**web**: Lowercase.
**webpage**: One word.
**website**: One word.
**Wi-Fi**: Hyphenate. Capitalize.

### Mouse Interactions

Most of the time, don't talk about the mouse—use input-neutral terms like _select_.

**click**: Use to describe selecting an item with the mouse. Don't use _click on_.
**double-click**: Hyphenate. Don't use _double-click on_.
**drag**: Use for holding a button while moving the mouse. Don't use _click and drag_ or _drag and drop_.
**hover over, point to**: Use to describe moving the pointer over an element without selecting it. Don't use _mouse over_.
**right-click**: Use for clicking with the secondary mouse button.
**pointer**: Use to refer to the on-screen pointer. Use _cursor_ only for the text insertion point.
**scroll**: Use for moving content using a scroll bar or mouse wheel.
**zoom in, zoom out**: Verbs for changing magnification.

### Touch and Pen Interactions

Use input-neutral terms when possible. For touch-specific content:

**tap**: Use instead of _click_. Don't use _tap on_.
**double-tap**: Hyphenate. Use instead of _double-click_. Don't use _double-tap on_.
**tap and hold**: Use only if required by the software. Don't use _touch and hold_.
**flick**: Use to describe moving fingers to scroll through items. Don't use _scroll_.
**pan**: Use for moving the screen in multiple directions at a controlled rate. Don't use _drag_ or _scroll_.
**pinch, stretch**: Use to describe zooming in/out with two fingers.
**swipe**: Use for a short, quick movement opposite to scroll direction.
**select and hold**: Use to describe pressing and holding an element.

### Developer and Technical Terms

#### Programming

**add-in**: Hyphenate.
**app**: Use _app_ instead of _application_ for modern Windows apps and mobile apps.
**cmdlet**: Lowercase.
**dataset**: One word.
**GitHub**: Capitalize G and H.
**JavaScript**: One word, capital J and S.
**metadata**: One word.
**.NET**: Always starts with a dot and is capitalized.
**plug-in**: Hyphenate.
**PowerShell**: One word, capital P and S.
**real-time**: Hyphenate as an adjective. Two words as a noun (_real time_).
**style sheet**: Two words.
**workgroup**: One word.

#### Protocols and Standards

**DNS**: Domain Name System.
**FTP**: File Transfer Protocol.
**HTML**: Hypertext Markup Language.
**HTTP, HTTPS**: Hypertext Transfer Protocol, Hypertext Transfer Protocol Secure.
**I/O**: Input/output.
**IP address**: Internet Protocol address.
**OS**: Operating system.
**PDF**: Portable Document Format.
**SQL**: Structured Query Language. Pronounced as letters or "sequel". Use _a SQL database_.
**SSL**: Secure Sockets Layer.
**UI**: User interface.
**URL**: Uniform Resource Locator.

#### Products and Platforms

**Bluetooth**: Capitalize.
**Control Panel**: Capitalize.
**Cortana**: Capitalize.

### Dates and Times

#### Dates

- Use format: _Month Day, Year_ (e.g., _July 31, 2016_).
- Don't use ordinals (_1st_, _12th_, _23rd_) for dates.
- Capitalize days of the week and months.
- Abbreviate only when space is limited: _Sun_, _Mon_, _Tue_, _Wed_, _Thu_, _Fri_, _Sat_; _Jan_, _Feb_, _Mar_, etc.

#### Times

- Use numerals with AM/PM: _2:00 PM_, _7:30 AM_.
- Use _noon_ and _midnight_, not _12:00 PM_ or _12:00 AM_.
- Include time zone when relevant. Capitalize: _Pacific Time_, _Eastern Time_.
- For ranges, use _to_ in text (_10:00 AM to 2:00 PM_) and en dash in schedules (_10:00 AM–2:00 PM_).

### Units of Measure

- Use numerals for all measurements, even under 10: _3 ft_, _5 in._, _1.76 lb_.
- Insert a space between number and unit: _13.5 inches_, _8.0 MP_.
- Hyphenate when modifying a noun: _13.5-inch display_, _8.0-MP camera_.
- Use commas in numbers with four or more digits: _1,093 MB_.
- Use singular for 1, plural for all other numbers: _1 point_, _0.5 points_, _12 points_.
- Spell out _by_ in dimensions, except use × for tile sizes, screen resolutions, and paper sizes: _10 by 12 ft room_, _1280 × 1024_.

#### Common Abbreviations

| Term            | Abbreviation |
| :-------------- | :----------- |
| gigabyte        | GB           |
| megabyte        | MB           |
| kilobyte        | KB           |
| terabyte        | TB           |
| gigahertz       | GHz          |
| megahertz       | MHz          |
| pixels per inch | PPI          |
| dots per inch   | dpi          |

### Lists

#### Bulleted Lists

- Use for items that have something in common but don't need a particular order.
- Each item should have a consistent structure (all nouns, all verb phrases, etc.).

#### Numbered Lists

- Use for sequential items (procedures) or prioritized items (top 10 lists).
- Use no more than 7 steps.

#### Formatting

- Capitalize the first word of each list item.
- Don't use semicolons, commas, or conjunctions at the end of list items.
- Don't use periods unless items are complete sentences.
- If list items complete an introductory fragment ending with a colon, use periods after all items if any form a complete sentence.

### Common Spelling and Usage

#### Prefixes

**auto-**: Hyphenate if the stem word is capitalized or to avoid confusion.
**multi-**: Generally do not hyphenate words beginning with _multi_ (e.g., _multicast_, _multifactor_).
**non-**: Hyphenate if the stem word is capitalized (e.g., _non-Microsoft_) or to avoid confusion.

#### Capitalization

**account, administrator, beta, client**: Lowercase.
**administrator**: Use _administrator_, not _admin_, unless space is limited.
**OK**: All caps. Do not use _Okay_ or _ok_.
**ZIP Code**: Capitalize _ZIP_ and _Code_.

#### Word Forms

**bit, byte**: Spell out unless in a measurement with a number (e.g., _32-bit_).
**cursor**: Use _pointer_ for the mouse. Use _cursor_ for the insertion point in text.
**user**: Avoid if possible. Use _you_ to address the reader.
**end user**: Avoid. Use _customer_, _user_, or _you_.
**host name, user name, time zone, knowledge base**: Two words.
**x-axis, y-axis**: Hyphenate. Lowercase.

#### Phrases to Avoid

| Avoid              | Use instead                        |
| :----------------- | :--------------------------------- |
| access key, hotkey | keyboard shortcut                  |
| click              | select                             |
| etc.               | and so on                          |
| ex.                | for example                        |
| FAQ                | frequently asked questions         |
| i.e.               | that is                            |
| native             | (use carefully)                    |
| uncheck            | clear (e.g., _clear the checkbox_) |
| vs.                | vs. (with period)                  |

#### Ensure vs. Insure

_Ensure_ means to make sure something happens. _Insure_ refers to insurance.

### Headings

- Use sentence-style capitalization.
- Keep headings short—ideally one line.
- Don't end headings with periods. Question marks and exclamation points are OK if needed.
- Use parallel structure for headings at the same level.
- Don't use ampersands (&) or plus signs (+) unless referring to UI.
- Avoid hyphens in headings (can cause awkward line breaks).
- Use _vs._, not _v._ or _versus_.

### Topic Guidelines

#### Accessibility

- **People-first language:** Refer to the person first, then the disability. Use _person with a disability_, not _disabled person_. Some communities prefer identity-first language—defer to their preferences.
- **Input-neutral verbs:** Use verbs that apply to all input methods (mouse, touch, keyboard). Use _select_ instead of _click_ or _tap_.
- **Alt text:** Provide meaningful alt text for images.
- **Links:** Use descriptive link text (not _click here_).
- **Keyboard procedures:** Always document keyboard procedures, even if indicated in the UI.

##### Preferred Terms

| Preferred (people-first)                             | Acceptable (identity-first)                 | Do not use                                            |
| :--------------------------------------------------- | :------------------------------------------ | :---------------------------------------------------- |
| Person who is blind, person with low vision          | Blind person                                | Sight-impaired, vision-impaired                       |
| Person who is deaf, person with a hearing disability | Deaf person                                 | Hearing-impaired                                      |
| Person with limited mobility                         | Physically disabled person, wheelchair user | Crippled, lame, handicapped                           |
| Is unable to speak, uses sign language               | —                                           | Dumb, mute                                            |
| Has multiple sclerosis, cerebral palsy               | —                                           | Affected by, stricken with, suffers from, a victim of |
| Person without a disability                          | Non-disabled person                         | Normal person, healthy person                         |
| Person with a disability                             | Disabled person                             | The handicapped, people with handicaps                |
| Person with cognitive disabilities                   | Learning disabled                           | Slow learner, mentally handicapped, special needs     |

#### Acronyms

- **Spell out:** Spell out acronyms on the first mention, followed by the acronym in parentheses.
- **Plurals:** Add _s_ to make an acronym plural (e.g., _APIs_). Do not use an apostrophe.
- **Possessives:** Avoid using the possessive form of an acronym.
- **Common acronyms:** Some acronyms (USB, URL, FAQ) do not need to be spelled out.
- **Articles:** Use _a_ or _an_ depending on pronunciation (e.g., _a URL_, _an ISP_).
- **Titles:** Avoid using acronyms in titles unless they are keywords.

#### Bias-free Communication

- **Gender-neutral:** Use _you_ or _they_ instead of _he/she_. Avoid gendered terms like _chairman_ (use _chair_) or _manpower_ (use _workforce_).
- **Inclusive language:** Avoid terms like _master/slave_ (use _primary/secondary_), _whitelist/blacklist_ (use _allowlist/blocklist_).
- **Militaristic language:** Avoid terms like _kill chain_, _DMZ_ (use _perimeter network_), _abort_, _terminate_.
- **Focus on people:** Focus on people, not disabilities. Don't use words that imply pity (_suffering from_).
- **Diversity:** Use diverse names and examples in fictitious scenarios.

#### Capitalization

- **Sentence-style:** Use sentence-style capitalization for titles, headings, and UI labels (capitalize only the first word and proper nouns).
- **Proper nouns:** Capitalize product names and proper nouns.
- **Acronyms:** Do not capitalize the spelled-out form of an acronym unless it is a proper noun.
- **All caps:** Do not use all caps for emphasis.
- **Internal capitalization:** Do not use internal capitalization (e.g., _e-Book_) unless it is part of a brand name.

#### Chatbots

- **Terminology:** Use _bot_ or _virtual agent_. Do not use _robot_.
- **Transparency:** Make it clear to the user that they are interacting with a bot.
- **Tone:** Adapt the tone to the context (empathetic for support, casual for chat).
- **Confirm intent:** Confirm the customer's intent before acting.
- **Break up messages:** Break up long messages into separate, readable blocks.
- **Closure:** Mimic the sense of closure in human interactions (e.g., "Is there anything else?").

#### Developer Content

- **Code style:** Use code style (monospace) for keywords, variable names, and code snippets.
- **Code examples:** Provide concise, secure, and copy-pasteable code examples. Explain the scenario and requirements.
- **Reference docs:** Follow a consistent structure (Description, Syntax, Parameters, Return Value, Examples).
- **Formatting:** Use consistent formatting for elements like _Classes_, _Methods_, _Parameters_.

#### Global Communications

- **Idioms:** Avoid idioms and colloquialisms that may be hard to translate.
- **Currency:** Use the currency code (e.g., _USD_) when referring to specific amounts.
- **Date format:** Use _Month Day, Year_ (e.g., _July 31, 2016_) to avoid ambiguity.
- **Art:** Choose simple, generic images. Avoid hand signs and holiday images.
- **Names:** Use _First name_ and _Last name_ or _Full name_. Use _Title_ instead of _Honorific_.
- **Time and place:** Include time zones. Use _Country/Region_.

#### Grammar

- **Voice:** Use active voice (where the subject performs the action). Passive voice is OK occasionally for variety or to emphasize the action.
- **Tense:** Use present tense. Avoid _will_, _was_, and verbs ending in _-ed_.
- **Mood:** Use indicative mood for statements of fact. Use imperative mood for procedures. Use subjunctive mood sparingly.
- **Person:** Use second person (_you_) to address the user. Don't use _he_ or _she_ in generic references—use _you_, _they_, or refer to a role.
- **Contractions:** Use common contractions (_it's_, _you're_, _don't_, _we're_, _let's_). Don't form contractions from nouns and verbs (_Microsoft's developing_).
- **Verbs:** Use precise verbs. Start statements with verbs. Edit out _you can_, _there is_, _there are_, _there were_.
- **Modifiers:** Keep modifiers close to the words they modify. Place _only_ carefully.
- **Words ending in -ing:** Be clear about the role (verb, adjective, or noun). _Meeting requirements_ could mean discussing requirements or fulfilling them.
- **Prepositional phrases:** Avoid consecutive prepositional phrases. They're hard to read.

#### Numbers

##### Spell Out (Zero–Nine)

- Whole numbers zero through nine, unless space is limited.
- One of the numbers when two numbers from separate categories appear together (_two 3-page articles_).
- At the beginning of a sentence.
- Ordinal numbers (_first_, _second_). Don't add _-ly_ (_firstly_).

##### Use Numerals

- Numbers 10 or greater.
- Numbers in UI.
- Measurements (distance, temperature, volume, weight, pixels, points).
- Time of day (_7:30 AM_).
- Percentages (_5%_)—use the percent sign with numerals.
- Dimensions. Use × for tile sizes, screen resolutions, paper sizes (_1280 × 1024_).
- Numbers customers are directed to type.
- Round numbers of 1 million or more (_1.5 million_).

##### Commas

- Use in numbers with four or more digits (_1,000_, _10,000_).
- Exception: For years and baud, use commas only with five or more digits (_2024_, _14,400 baud_).
- Don't use in page numbers, street addresses, or decimal fractions.

##### Ranges

- Use _from_ and _through_ in text (_from 10 through 15_).
- Use en dash in tables, UI, or where space is limited (_10–15_).
- Don't use _from_ before an en dash range.

##### Fractions and Decimals

- Hyphenate spelled-out fractions (_one-third_, but _three sixty-fourths_).
- Include a zero before decimals less than one (_0.5_) unless the customer types the value.
- Align decimals on the decimal point in tables.

#### Procedures and Instructions

- **Steps:** Use numbered lists for steps. Limit to 7 steps. Write a complete sentence for each step.
- **Verbs:** Start each step with an imperative verb.
- **Formatting:** Use **bold** for UI elements (buttons, menus, dialog names). Don't use quotes or italics.
- **Single steps:** Use a bullet instead of the number 1.
- **Menu sequences:** Use right angle brackets with spaces: \*Select **Accounts** > **Other accounts** > **Add an account\***.

##### Input-Neutral Verbs

| Verb                    | Use for                                                |
| :---------------------- | :----------------------------------------------------- |
| Open                    | Apps, shortcut menus, files, folders                   |
| Close                   | Apps, dialog boxes, windows, files, folders            |
| Leave                   | Websites and webpages                                  |
| Go to                   | A menu or place in the UI (search, ribbon, tab)        |
| Select                  | UI options, values, links, menu items                  |
| Select and hold         | Pressing and holding an element for about a second     |
| Clear                   | Removing the selection from a checkbox                 |
| Choose                  | An exclusive option where only one value can be chosen |
| Enter                   | Instructing the reader to type or enter a value        |
| Move                    | Moving something from one place to another             |
| Zoom, zoom in, zoom out | Changing magnification                                 |

- **Avoid:** _press_, _press and hold_, _right-click_, _click_, _tap_ (unless input-specific).

##### Example

1.  Go to **Settings**.
2.  Select **Accounts**.
3.  Enter your password.
4.  Select **Save**.

#### Punctuation

- **Commas:** Use the Oxford comma (comma before the conjunction in a list of three or more items). Use after introductory phrases and to join independent clauses with a conjunction.
- **Periods:** Use one space after a period. Skip periods on headings, titles, subheadings, and list items that are three words or fewer.
- **Semicolons:** Avoid. Break into separate sentences or use a list.
- **Hyphens:** Use for compound adjectives (_sign-in page_, _real-time data_). Don't use unless leaving them out causes confusion.
- **Em dashes (—):** Use without spaces for breaks in thought.
- **En dashes (–):** Use for ranges (_10–15_) without spaces. Don't use _from_ before an en dash range.
- **Colons:** Use to introduce a list. Lowercase the word after a colon unless it's a proper noun or the start of a quotation.
- **Exclamation points:** Use sparingly. Save for when they count.
- **Question marks:** Use sparingly. Customers expect answers.
- **Quotation marks:** Place closing quotes outside commas and periods, inside other punctuation.
- **Apostrophes:** Use for contractions (_don't_) and possessives (_Insider's Guide_). Don't use for the possessive of _it_ (_its_).
- **Slashes:** Don't use as a substitute for _or_. OK for _Country/Region_ where space is limited.

#### Responsive Content

- **Paragraphs:** Keep paragraphs short (3-7 lines).
- **Headings:** Keep headings short and scannable (one line).
- **Short sections:** Break content into short sections.
- **Tables:** Limit the number of columns.

#### Text Formatting

- **Bold:** Use bold for UI elements.
- **Italic:** Use italic for the first mention of a new term, or for book titles.
- **Capitalization:** Do not use all caps for emphasis.
- **Left alignment:** Use left alignment. Do not center text.
- **Line spacing:** Do not compress line spacing.

#### URLs

- **Format:** Use lowercase for URLs. Omit _http://www_ if possible (e.g., _microsoft.com_).
- **Link text:** Use descriptive link text (e.g., _Go to the Windows page_), not _click here_.
- **Protocol:** Don't include _https://_ unless it's not HTTP.
- **Trailing slash:** Omit the trailing slash.

#### Word Choice

- **Simple words:** Use simple, everyday words (_use_ instead of _utilize_, _try_ instead of _attempt to_).
- **Consistency:** Use the same term for the same concept throughout.
- **Jargon:** Avoid jargon unless the audience is technical.
- **Contractions:** Use common contractions to sound friendly.
- **Technical terms:** Define in context if the audience might not understand. Use plain language when possible.
- **Avoid ambiguity:** Don't use words with multiple meanings. Don't give technical meanings to common words (_bucket_ to mean _group_).
- **Don't create new words:** Research existing terminology before creating new terms.
- **Don't personify:** Don't attribute human characteristics to devices and products. They don't _think_, _feel_, _want_, or _see_.

##### Common Replacements

| Replace              | With                |
| :------------------- | :------------------ |
| utilize              | use                 |
| attempt to           | try                 |
| in order to          | to                  |
| a number of          | several, many       |
| due to the fact that | because             |
| prior to             | before              |
| subsequent to        | after               |
| in the event that    | if                  |
| leverage             | use                 |
| facilitate           | help, make possible |
