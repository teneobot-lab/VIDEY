-- Satu Heartbeat untuk semua tugas berkala.
-- Pakai: Scheduler.add("Nama", interval_detik, fn)   (interval 0 = tiap frame)
-- Error tiap tugas ditangkap Hub.safe dan tampil di Dashboard > Diagnostik.
local Hub = ...
local RunService = game:GetService("RunService")

local Scheduler = { fps = 60, tasks = {} }

function Scheduler.add(name, interval, fn)
    Scheduler.tasks[#Scheduler.tasks + 1] = { name = name, interval = interval, fn = fn, acc = 0 }
end

Hub.track(RunService.Heartbeat:Connect(function(dt)
    if Hub.Dead then return end
    Scheduler.fps = Scheduler.fps * 0.9 + (1 / math.max(dt, 1e-3)) * 0.1
    for _, t in ipairs(Scheduler.tasks) do
        if t.interval <= 0 then
            Hub.safe(t.name, t.fn, dt)
        else
            t.acc += dt
            if t.acc >= t.interval then
                t.acc = 0
                Hub.safe(t.name, t.fn, dt)
            end
        end
    end
end))

return Scheduler
