import { Card, CardHead, Chip, I, when } from "../components/ui";

export default function ProjectsPage({ projects, jobs }) {
  return (
    <div className="pt-5 sm:pt-6 max-w-[900px]">
      <Card>
        <CardHead icon={I.home} title="Projects" note="Work you are getting priced" />
        <div className="divide-y divide-[#1C1C1A]">
          {projects.map((p) => (
            <div key={p._id} className="px-4 sm:px-6 py-5 flex flex-wrap items-center gap-4">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2.5">
                  <span className="display text-[length:var(--step-1)] font-semibold">{p.name}</span>
                  <Chip tone={p.revision > 1 ? "warn" : "good"}>
                    {p.revision > 1 ? "job changed" : "as first described"}
                  </Chip>
                </div>
                <p className="text-[length:var(--step--1)] text-[#B5B3AA] mt-1.5 leading-5">
                  {p.client} · {p.scopeNote}
                </p>
              </div>
              <div className="text-right shrink-0">
                <p className="text-[length:var(--step--1)] text-[#D6D4CC]">
                  {jobs?.filter((j) => j.projectId === p._id).length ?? 0} job
                </p>
                <p className="text-[length:var(--step--2)] text-[#6E6C66] mt-1">{when(p.createdAt)}</p>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
