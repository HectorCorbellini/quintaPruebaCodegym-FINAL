package com.codegym.jira.bugtracking.task;

import com.codegym.jira.bugtracking.Handlers;
import com.codegym.jira.common.error.DataConflictException;
import com.codegym.jira.login.AuthUser;
import com.codegym.jira.bugtracking.task.to.ActivityTo;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static com.codegym.jira.bugtracking.task.TaskUtil.getLatestValue;

@Service
@RequiredArgsConstructor
public class ActivityService {
    private final TaskRepository taskRepository;

    private final Handlers.ActivityHandler handler;

    private static void checkBelong(HasAuthorId activity) {
        if (activity.getAuthorId() != AuthUser.authId()) {
            throw new DataConflictException("Activity " + activity.getId() + " doesn't belong to " + AuthUser.get());
        }
    }

    @Transactional
    public Activity create(ActivityTo activityTo) {
        checkBelong(activityTo);
        if (activityTo.getStatusCode() != null || activityTo.getTypeCode() != null) {
            Task task = taskRepository.getExisted(activityTo.getTaskId());
            if (activityTo.getStatusCode() != null) {
                task.checkAndSetStatusCode(activityTo.getStatusCode());
            }
            if (activityTo.getTypeCode() != null) {
                task.setTypeCode(activityTo.getTypeCode());
            }
        }
        return handler.createFromTo(activityTo);
    }

    @Transactional
    public void update(ActivityTo activityTo, long id) {
        checkBelong(handler.getRepository().getExisted(activityTo.getId()));
        handler.updateFromTo(activityTo, id);
        updateTaskIfRequired(activityTo.getTaskId(), activityTo.getStatusCode(), activityTo.getTypeCode());
    }

    @Transactional
    public void delete(long id) {
        Activity activity = handler.getRepository().getExisted(id);
        checkBelong(activity);
        handler.delete(activity.id());
        updateTaskIfRequired(activity.getTaskId(), activity.getStatusCode(), activity.getTypeCode());
    }

    private void updateTaskIfRequired(long taskId, String activityStatus, String activityType) {
        if (activityStatus != null) {
            Task task = taskRepository.getExisted(taskId);
            List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(task.id());
            String latestStatus = getLatestValue(activities, Activity::getStatusCode);
            if (latestStatus == null) {
                throw new DataConflictException("Primary activity cannot be delete or update with null values");
            }
            task.setStatusCode(latestStatus);
        }
        if (activityType != null) {
            Task task = taskRepository.getExisted(taskId);
            List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(task.id());
            String latestType = getLatestValue(activities, Activity::getTypeCode);
            if (latestType == null) {
                throw new DataConflictException("Primary activity cannot be delete or update with null values");
            }
            task.setTypeCode(latestType);
        }
    }
    
    /**
     * Calcula el tiempo que una tarea estuvo en estado "in_progress" hasta "ready_for_review".
     * 
     * @param taskId ID de la tarea
     * @return Duración en minutos, o null si no se puede calcular
     */
    @Transactional(readOnly = true)
    public Long calculateDevelopmentTime(long taskId) {
        List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(taskId);
        
        // Ordenamos las actividades de más antiguas a más recientes para procesarlas cronológicamente
        activities.sort((a1, a2) -> a1.getUpdated().compareTo(a2.getUpdated()));
        
        LocalDateTime inProgressTime = null;
        LocalDateTime readyForReviewTime = null;
        
        for (Activity activity : activities) {
            if (activity.getStatusCode() != null) {
                if ("in_progress".equals(activity.getStatusCode()) && inProgressTime == null) {
                    inProgressTime = activity.getUpdated();
                } else if ("ready_for_review".equals(activity.getStatusCode()) && inProgressTime != null) {
                    readyForReviewTime = activity.getUpdated();
                    break; // Encontramos la primera transición de in_progress a ready_for_review
                }
            }
        }
        
        if (inProgressTime != null && readyForReviewTime != null) {
            return Duration.between(inProgressTime, readyForReviewTime).toMinutes();
        }
        
        return null; // No se encontró una transición completa
    }
    
    /**
     * Calcula el tiempo que una tarea estuvo en estado "ready_for_review" hasta "done".
     * 
     * @param taskId ID de la tarea
     * @return Duración en minutos, o null si no se puede calcular
     */
    @Transactional(readOnly = true)
    public Long calculateReviewTime(long taskId) {
        List<Activity> activities = handler.getRepository().findAllByTaskIdOrderByUpdatedDesc(taskId);
        
        // Ordenamos las actividades de más antiguas a más recientes para procesarlas cronológicamente
        activities.sort((a1, a2) -> a1.getUpdated().compareTo(a2.getUpdated()));
        
        LocalDateTime readyForReviewTime = null;
        LocalDateTime doneTime = null;
        
        for (Activity activity : activities) {
            if (activity.getStatusCode() != null) {
                if ("ready_for_review".equals(activity.getStatusCode()) && readyForReviewTime == null) {
                    readyForReviewTime = activity.getUpdated();
                } else if ("done".equals(activity.getStatusCode()) && readyForReviewTime != null) {
                    doneTime = activity.getUpdated();
                    break; // Encontramos la primera transición de ready_for_review a done
                }
            }
        }
        
        if (readyForReviewTime != null && doneTime != null) {
            return Duration.between(readyForReviewTime, doneTime).toMinutes();
        }
        
        return null; // No se encontró una transición completa
    }
}
